#!/usr/bin/env bash
# Exercises the "Repo self-checks pass (tests/)" step of the shared workflow.
#
# The step is extracted from skill-check.yml rather than retyped, so what is
# tested is what ships. This repo tracks no other check, so without this file
# the step's only exercised path here would be the empty-repo bypass.
#
# Offline: no network, no gh, no package install.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 - "$root/.github/workflows/skill-check.yml" "$work/step.sh" <<'PY'
import sys, pathlib, yaml
wf = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
steps = [s for s in wf["jobs"]["validate"]["steps"]
         if s.get("name", "").startswith("Repo self-checks")]
if len(steps) != 1:
    sys.exit(f"expected exactly one self-checks step, found {len(steps)}")
pathlib.Path(sys.argv[2]).write_text("#!/usr/bin/env bash\n" + steps[0]["run"],
                                     encoding="utf-8")
PY

script() { printf '#!/usr/bin/env bash\n%s\n' "$1" > "$2"; }

repo() {  # repo <name> -- makes $work/<name> a git repo, prints its path
    local d="$work/$1"
    mkdir -p "$d/tests"
    git -C "$d" init -q
    printf '%s' "$d"
}

track() { git -C "$1" add -A && git -C "$1" -c user.email=t@t -c user.name=t commit -qm fixture; }

fail=0
expect() {  # expect <label> <dir> <want-rc> <want-substring>
    local label=$1 dir=$2 want_rc=$3 want=$4 out rc=0
    out=$(cd "$dir" && bash "$work/step.sh" 2>&1) || rc=$?
    if [ "$rc" = "$want_rc" ] && printf '%s' "$out" | grep -qF -- "$want"; then
        echo "ok    $label"
    else
        printf 'FAIL  %s (rc=%s, wanted %s and %s)\n%s\n' \
            "$label" "$rc" "$want_rc" "$want" "$out"
        fail=1
    fi
}

d=$(repo empty); rmdir "$d/tests"; touch "$d/README.md"; track "$d"
expect "a repo with no tests passes and says so" "$d" 0 "no tests tracked"

d=$(repo two)
script 'echo a' "$d/tests/a.sh"; script 'echo b' "$d/tests/b.sh"; track "$d"
expect "every tests/*.sh runs and the count is reported" "$d" 0 "2 check(s) passed"

d=$(repo red)
script 'exit 1' "$d/tests/a.sh"; track "$d"
expect "a failing check turns the job red" "$d" 1 "tests/a.sh"

d=$(repo entry)
script 'echo runner' "$d/tests/run.sh"
script 'echo HELPER RAN; exit 1' "$d/tests/helper.sh"; track "$d"
expect "tests/run.sh is the sole entry point" "$d" 0 "1 check(s) passed"

d=$(repo scoped); mkdir -p "$d/tests/sub" "$d/lib/vendor/tests"
script 'echo top' "$d/tests/top.sh"
script 'exit 1' "$d/tests/sub/deep.sh"
script 'exit 1' "$d/lib/vendor/tests/y.sh"; track "$d"
expect "only direct children of the repo-root tests/ are discovered" "$d" 0 "1 check(s) passed"

d=$(repo untracked)
script 'echo tracked' "$d/tests/a.sh"; track "$d"
script 'echo HIJACKED; exit 1' "$d/tests/run.sh"
expect "an untracked tests/run.sh cannot hijack discovery" "$d" 0 "1 check(s) passed"

mkdir -p "$work/notgit"
expect "a git failure fails loudly instead of reading as no tests" "$work/notgit" 128 "not a git repository"

[ "$fail" -eq 0 ] || exit 1
echo "ok    self-checks step behaves"
