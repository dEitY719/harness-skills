#!/usr/bin/env bash
# Shared helpers for the tests/ checks that exercise a shared-workflow step.
#
# Not a check itself. The workflow discovers `:(glob)tests/*.sh`, where `*`
# never crosses `/`, so nothing under tests/lib/ is ever run as a check --
# tests/self-checks-step.sh asserts exactly that, and README "Where a repo's
# tests live" names tests/lib/ as the home for a helper.
#
# Extraction is the load-bearing part: it couples to skill-check.yml's shape
# (jobs.validate.steps, and rebuilding a step's `run` into a script), so it
# belongs in one place rather than copied per check.
#
# A caller sets `root`, `work` and `fail` before sourcing, then points `step`
# at whichever extracted step `expect` should run -- which is why shellcheck
# cannot see them assigned when it lints this file on its own.
# shellcheck shell=bash
# shellcheck disable=SC2154,SC2034

extract() {  # extract <step-name-prefix> <out-path>
    python3 - "$root/.github/workflows/skill-check.yml" "$1" "$2" <<'PY'
import sys, pathlib, yaml
wf = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
steps = [s for s in wf["jobs"]["validate"]["steps"]
         if s.get("name", "").startswith(sys.argv[2])]
if len(steps) != 1:
    sys.exit(f"expected exactly one {sys.argv[2]!r} step, found {len(steps)}")
pathlib.Path(sys.argv[3]).write_text("#!/usr/bin/env bash\n" + steps[0]["run"],
                                     encoding="utf-8")
PY
}

expect() {  # expect <label> <dir> <want-rc> <want-substring> -- runs $step in <dir>
    local label=$1 dir=$2 want_rc=$3 want=$4 out rc=0
    out=$(cd "$dir" && bash "$step" 2>&1) || rc=$?
    if [ "$rc" = "$want_rc" ] && printf '%s' "$out" | grep -qF -- "$want"; then
        echo "ok    $label"
    else
        printf 'FAIL  %s (rc=%s, wanted %s and %s)\n%s\n' \
            "$label" "$rc" "$want_rc" "$want" "$out"
        fail=1
    fi
}
