#!/usr/bin/env bash
# Exercises version-bump.yml's "Bump patch version" step.
#
# The step is extracted from the workflow rather than retyped, so what is
# tested is what ships. Each case pushes real commits to a local bare "origin"
# and runs the step in a fresh clone of it, the way actions/checkout leaves
# the runner, so the step's own `git push` lands in that origin.
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
extract "Bump patch version" "$step" version-bump.yml bump

g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }

# setup <name> <version>: a bare origin whose main holds all seven manifests at
# <version>, plus a dev clone to push from. The marketplace carries a second,
# unrelated "version" and odd spacing, to prove only the plugin value moves.
setup() {
    local v=$2
    origin=$work/$1.git dev=$work/$1-dev
    g init -q --bare "$origin"
    g clone -q "$origin" "$dev" 2>/dev/null
    mkdir -p "$dev"/{.claude-plugin,.codex-plugin,.kimi-plugin,.hermes-plugin,skills/a}
    printf '{\n  "name": "p",\n  "version": "%s",\n  "license": "MIT"\n}\n' "$v" \
        | tee "$dev/.claude-plugin/plugin.json" "$dev/.codex-plugin/plugin.json" \
              "$dev/.kimi-plugin/plugin.json" >/dev/null
    printf '{\n    "name":"p",\n    "version" :  "%s"\n}\n' "$v" > "$dev/gemini-extension.json"
    printf '{"name": "p", "version": "%s", "private": true}\n' "$v" > "$dev/package.json"
    printf '{\n  "metadata": { "version": "9.9.9" },\n  "plugins": [\n    { "name": "p", "version": "%s" }\n  ]\n}\n' \
        "$v" > "$dev/.claude-plugin/marketplace.json"
    printf 'name: p\nversion: %s\ndescription: d\n' "$v" > "$dev/.hermes-plugin/plugin.yaml"
    printf -- '---\nname: a\n---\n' > "$dev/skills/a/SKILL.md"
    g -C "$dev" add -A && g -C "$dev" commit -qm seed && g -C "$dev" push -q origin main
}

# push_change <file> [version]: append to <file> in dev (and move plugin.json's
# version if given), push, then clone the pushed tip as the CI checkout.
push_change() {
    BEFORE=$(git -C "$dev" rev-parse HEAD)
    echo more >> "$dev/$1"
    if [ -n "${2:-}" ]; then
        sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$2\"/" "$dev/.claude-plugin/plugin.json"
    fi
    g -C "$dev" commit -qam change && g -C "$dev" push -q origin main
    AFTER=$(git -C "$dev" rev-parse HEAD)
    ci=$work/$(basename "$dev")-ci-$RANDOM
    g clone -q "$origin" "$ci"
    export BEFORE AFTER
}

origin_tip() { git -C "$origin" rev-parse main; }

export EVENT_NAME=push REF_NAME=main

setup skip 0.1.9
push_change skills/a/SKILL.md
EVENT_NAME=pull_request expect "a non-push event is skipped" "$ci" 0 "ok    skipped: not a push"
BEFORE=0000000000000000000000000000000000000000 \
    expect "a new branch (before all zeros) is skipped" "$ci" 0 "ok    skipped: new branch"
[ "$(origin_tip)" = "$AFTER" ] || { echo "FAIL  a skipped run pushed"; fail=1; }

setup docs 0.1.9
printf 'readme\n' > "$dev/README.md"; g -C "$dev" add README.md
push_change README.md
expect "an unshipped change is left alone" "$ci" 0 "ok    no shipped content changed"
[ "$(origin_tip)" = "$AFTER" ] || { echo "FAIL  an unshipped change pushed"; fail=1; }

setup bump 0.1.9
push_change skills/a/SKILL.md
expect "a shipped change without a bump is bumped" "$ci" 0 "ok    bumped 0.1.9 -> 0.1.10"
tip=$(origin_tip)
if [ "$tip" = "$AFTER" ] || [ "$(git -C "$origin" rev-parse "$tip^")" != "$AFTER" ]; then
    echo "FAIL  origin main does not carry exactly one bump commit on top"; fail=1
fi
[ "$(git -C "$origin" log -1 --format='%an <%ae>|%s' main)" = \
  "github-actions[bot] <41898583+github-actions[bot]@users.noreply.github.com>|chore(release): bump version to 0.1.10" ] \
    || { echo "FAIL  bump commit author or subject"; git -C "$origin" log -1 --format='%an <%ae>|%s' main; fail=1; }
git -C "$origin" log -1 --format=%b main | grep -qF "${BEFORE:0:7}..${AFTER:0:7}" \
    || { echo "FAIL  bump commit body lacks the shipped range"; fail=1; }
changed=$(git -C "$origin" diff --name-only "$AFTER" main | wc -l)
[ "$changed" -eq 7 ] || { echo "FAIL  bump touched $changed files, wanted 7"; fail=1; }
# Every changed line is a version line, and every one of them now says 0.1.10;
# the unrelated 9.9.9 and all other bytes are untouched.
lines=$(git -C "$origin" diff -U0 "$AFTER" main | grep -E '^[-+][^-+]' || true)
if printf '%s\n' "$lines" | grep -v version | grep -q . \
   || [ "$(printf '%s\n' "$lines" | grep -c '^+.*0\.1\.10')" -ne 7 ] \
   || [ "$(printf '%s\n' "$lines" | grep -c '^-.*0\.1\.9')" -ne 7 ]; then
    printf 'FAIL  bump diff is not exactly seven version lines\n%s\n' "$lines"; fail=1
else
    echo "ok    ...all seven sites moved, nothing else changed"
fi

setup moved 0.1.9
push_change skills/a/SKILL.md 0.2.0
expect "a version already moved is respected" "$ci" 0 "ok    version already moved 0.1.9 -> 0.2.0"
[ "$(origin_tip)" = "$AFTER" ] || { echo "FAIL  a moved version pushed"; fail=1; }

setup odd 0.2.0-rc1
push_change skills/a/SKILL.md
expect "a non-X.Y.Z version fails" "$ci" 1 "FAIL  version '0.2.0-rc1' is not plain X.Y.Z"
[ "$(origin_tip)" = "$AFTER" ] || { echo "FAIL  a failed run pushed"; fail=1; }

[ "$fail" -eq 0 ] || exit 1
echo "ok    version-bump step behaves"
