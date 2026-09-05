#!/usr/bin/env bash
# Exercises the shared workflow's "Declared cross-file facts agree" step.
#
# The step is extracted from skill-check.yml rather than retyped, so what is
# tested is what ships. It also runs the set this repo really declares in
# validate.yml against this repo, so a config that only looks right fails here
# instead of in CI.
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
         if s.get("name", "").startswith("Declared cross-file facts")]
if len(steps) != 1:
    sys.exit(f"expected exactly one consistency step, found {len(steps)}")
pathlib.Path(sys.argv[2]).write_text("#!/usr/bin/env bash\n" + steps[0]["run"],
                                     encoding="utf-8")
PY

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

# A repo of two manifests and one prose file, the shape the license set gates.
fixture=$work/repo
mkdir -p "$fixture/skills/a"
printf 'MIT License\n\nCopyright (c) 2026\n' > "$fixture/LICENSE"
printf '{\n  "license": "MIT"\n}\n' > "$fixture/package.json"
printf -- '---\nname: a\nlicense: MIT\n---\n' > "$fixture/skills/a/SKILL.md"

agree=$(cat <<'YAML'
license:
  LICENSE: '^(MIT) License'
  package.json: '"license":\s*"([^"]+)"'
  'skills/*/SKILL.md': '^license:\s*(\S+)'
YAML
)

export CONSISTENCY_CHECKS=""
expect "a repo declaring no set passes and says so" "$fixture" 0 "no consistency sets declared"

CONSISTENCY_CHECKS=$agree
expect "agreeing sites pass, with the value and the count" "$fixture" 0 "ok    license = MIT across 3 file(s)"

printf '{\n  "license": "Apache-2.0"\n}\n' > "$fixture/package.json"
expect "one flipped value fails" "$fixture" 1 "sites disagree: ['Apache-2.0', 'MIT']"
expect "...naming every file and its value" "$fixture" 1 "Apache-2.0	package.json"
printf '{\n  "license": "MIT"\n}\n' > "$fixture/package.json"

CONSISTENCY_CHECKS='license:
  nope/*.json: ^(x)$
'
expect "a glob matching nothing fails instead of checking nothing" "$fixture" 1 "matched no file"

CONSISTENCY_CHECKS='license:
  package.json: ^license:\s*(\S+)
'
expect "a file the regex cannot match fails, by name" "$fixture" 1 "package.json has no capture-group match"

CONSISTENCY_CHECKS='license:
  package.json: "([unclosed"
'
expect "an unparseable regex is rejected, not a traceback" "$fixture" 1 "bad regex"

CONSISTENCY_CHECKS='just a string'
expect "a non-mapping input is rejected, not a traceback" "$fixture" 1 "must be a mapping"

# This repo's real declaration, run against this repo.
CONSISTENCY_CHECKS=$(python3 - "$root/.github/workflows/validate.yml" <<'PY'
import sys, pathlib, yaml
wf = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
sys.stdout.write(wf["jobs"]["validate"]["with"]["consistency-checks"])
PY
)
expect "validate.yml's own license set holds in this repo" "$root" 0 "ok    license = MIT"

[ "$fail" -eq 0 ] || exit 1
echo "ok    consistency step behaves"
