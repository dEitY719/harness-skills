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
fail=0
trap 'rm -rf "$work"' EXIT

# shellcheck source=tests/lib/step.sh
. "$root/tests/lib/step.sh"

step=$work/step.sh
extract "Declared cross-file facts" "$step"


# A git repo of two manifests and one prose file, the shape the license set
# gates. It has to be a real repo: discovery is `git ls-files`, so that an
# untracked scratch file cannot fail a caller's gate.
fixture=$work/repo
mkdir -p "$fixture/skills/a"
printf 'MIT License\n\nCopyright (c) 2026\n' > "$fixture/LICENSE"
printf '{\n  "license": "MIT"\n}\n' > "$fixture/package.json"
printf -- '---\nname: a\nlicense: MIT\n---\n' > "$fixture/skills/a/SKILL.md"
git -C "$fixture" init -q
git -C "$fixture" add -A
git -C "$fixture" -c user.email=t@t -c user.name=t commit -qm fixture

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

# An untracked file must not be able to turn a repo's gate red.
mkdir -p "$fixture/skills/scratch"
printf -- '---\nname: scratch\n---\n' > "$fixture/skills/scratch/SKILL.md"
expect "an untracked file is not discovered" "$fixture" 0 "ok    license = MIT across 3 file(s)"
rm -rf "$fixture/skills/scratch"

CONSISTENCY_CHECKS='license:
  nope/*.json: ^(x)$
'
expect "a glob matching nothing fails instead of checking nothing" "$fixture" 1 "matched no file"

CONSISTENCY_CHECKS='license:
  package.json: ^license:\s*(\S+)
'
expect "a file the regex cannot match fails, by name" "$fixture" 1 "package.json has no capture-group match"

CONSISTENCY_CHECKS=$(cat <<'YAML'
license:
  package.json: '"license":\s*"([^"]+)"'
  '*.json': '"license":\s*"([^"]+)"'
YAML
)
expect "two globs matching one file are rejected, not last-wins" "$fixture" 1 "matched by two globs"

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
