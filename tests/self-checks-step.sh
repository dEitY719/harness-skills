#!/usr/bin/env bash
# Exercises the two shared-workflow steps that discover files with git:
# "Repo self-checks pass (tests/)" and "Shell scripts pass shellcheck (sh:check)".
#
# Each step is extracted from skill-check.yml rather than retyped, so what is
# tested is what ships. This repo tracks no other check, so without this file
# the self-checks step's only exercised path here would be the empty-repo
# bypass, and the shellcheck step's discovery would not be exercised at all.
#
# Offline: no network, no gh, no package install. Every shellcheck case is
# shaped to return before the apt-get install, so what is asserted is purely
# discovery.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
work=$(mktemp -d)
fail=0
trap 'rm -rf "$work"' EXIT

# shellcheck source=tests/lib/step.sh
. "$root/tests/lib/step.sh"

extract "Repo self-checks" "$work/self-checks.sh"
extract "Shell scripts pass shellcheck" "$work/shellcheck.sh"
step=$work/self-checks.sh

script() { printf '#!/usr/bin/env bash\n%s\n' "$1" > "$2"; }

repo() {  # repo <name> -- makes $work/<name> a git repo, prints its path
    local d="$work/$1"
    mkdir -p "$d/tests"
    git -C "$d" init -q
    printf '%s' "$d"
}

track() { git -C "$1" add -A && git -C "$1" -c user.email=t@t -c user.name=t commit -qm fixture; }


mkdir -p "$work/notgit"

# --- Repo self-checks pass (tests/) ---

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

expect "a git failure fails loudly instead of reading as no tests" "$work/notgit" 128 "not a git repository"

# --- Shell scripts pass shellcheck (sh:check) ---
#
# Same trap, same fix: discovery must never turn "git failed" into "nothing to
# check". The exclude input is caller-supplied, so a degenerate value has to be
# rejected rather than sanitised into an empty skip list.

step=$work/shellcheck.sh
export SHELLCHECK_EXCLUDE_PATHS="lib/vendor/"

d=$(repo sc-empty); touch "$d/README.md"; track "$d"
expect "no tracked .sh passes and says so" "$d" 0 "no shell scripts to check"

d=$(repo sc-vendor); mkdir -p "$d/lib/vendor"
script 'echo v' "$d/lib/vendor/v.sh"; track "$d"
expect "the excluded tree is subtracted, leaving nothing to check" "$d" 0 "no shell scripts to check"
expect "the skip list is announced" "$d" 0 ":(exclude)lib/vendor"

expect "a git failure fails loudly instead of reading as no scripts" "$work/notgit" 128 "not a git repository"

SHELLCHECK_EXCLUDE_PATHS="/"
expect "a degenerate '/' exclude is rejected, not quietly dropped" "$d" 1 "would exclude the whole repo"

# --- the class, not the two sites ---
#
# Both fixed steps used to discover through `mapfile/read < <(git ls-files)`,
# where a process substitution hides git's exit status from `set -e`. Nothing
# lints these `run:` bodies, so nothing stopped a third site appearing -- and
# a third had appeared, in the JSON step, which no issue had noticed. Assert
# the shape is gone from the whole file rather than fixing sites one at a time.
bad=$(python3 - "$root/.github/workflows/skill-check.yml" <<'SCAN'
import re, sys, pathlib, yaml
wf = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for s in wf["jobs"]["validate"]["steps"]:
    # Comments are excluded: the fixed steps describe the shape they removed.
    code = "\n".join(ln for ln in s.get("run", "").splitlines()
                     if not ln.lstrip().startswith("#"))
    if re.search(r"<\s*<\(\s*git\b", code):
        print(s.get("name", "<unnamed>"))
SCAN
)
if [ -z "$bad" ]; then
    echo "ok    no step discovers through a process substitution"
else
    printf 'FAIL  these steps hide git exit status from set -e:\n%s\n' "$bad"
    fail=1
fi

[ "$fail" -eq 0 ] || exit 1
echo "ok    workflow discovery steps behave"
