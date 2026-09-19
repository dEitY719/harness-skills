#!/usr/bin/env bash
# Exercises the shared workflow's "Version bumped when shipped content changes"
# step.
#
# The step is extracted from skill-check.yml rather than retyped, so what is
# tested is what ships. Each case is a real clone of a local "origin" whose
# main holds the base, so the step's own shallow `git fetch` runs unmodified.
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
extract "Version bumped" "$step"

g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
manifest() { printf '{\n  "version": "%s"\n}\n' "$2" > "$1/.claude-plugin/plugin.json"; }

origin=$work/origin
mkdir -p "$origin/.claude-plugin" "$origin/skills/a"
manifest "$origin" 0.1.0
printf -- '---\nname: a\n---\n' > "$origin/skills/a/SKILL.md"
g -C "$origin" init -q
g -C "$origin" add -A
g -C "$origin" commit -qm base

# pr <name>: a fresh clone standing in for the PR merge commit. file:// makes
# the step's `--depth=1` fetch honoured instead of warned about.
pr() {
    local dir=$work/$1
    g clone -q "file://$origin" "$dir"
    printf '%s\n' "$dir"
}
commit() { g -C "$1" add -A && g -C "$1" commit -qm pr; }

export BASE_REF=main

EVENT_NAME=push
export EVENT_NAME
expect "a non-PR event is skipped, never failed" "$origin" 0 "ok    skipped: not a pull_request"
EVENT_NAME=pull_request

d=$(pr docs)
printf 'readme\n' > "$d/README.md"
commit "$d"
expect "a PR touching only unshipped files passes" "$d" 0 "ok    no shipped content changed"

d=$(pr nobump)
printf 'more\n' >> "$d/skills/a/SKILL.md"
commit "$d"
expect "a skills/ change without a bump fails" "$d" 1 \
    "FAIL  shipped content changed but version is still 0.1.0"
expect "...listing the changed shipped file" "$d" 1 "      skills/a/SKILL.md"

d=$(pr bump)
printf 'more\n' >> "$d/skills/a/SKILL.md"
manifest "$d" 0.2.0
commit "$d"
expect "a skills/ change with a bump passes" "$d" 0 "ok    version bumped 0.1.0 -> 0.2.0"

d=$(pr numeric)
printf 'more\n' >> "$d/skills/a/SKILL.md"
manifest "$d" 0.10.0
commit "$d"
expect "versions compare as integers, not strings" "$d" 0 "ok    version bumped 0.1.0 -> 0.10.0"

d=$(pr downgrade)
printf 'more\n' >> "$d/skills/a/SKILL.md"
manifest "$d" 0.0.9
commit "$d"
expect "a downgrade fails" "$d" 1 "version went 0.1.0 -> 0.0.9, not up"

d=$(pr prerelease)
printf 'more\n' >> "$d/skills/a/SKILL.md"
manifest "$d" 0.2.0-rc1
commit "$d"
expect "a non-numeric version only has to differ" "$d" 0 "ok    version bumped 0.1.0 -> 0.2.0-rc1"

[ "$fail" -eq 0 ] || exit 1
echo "ok    version-bump step behaves"
