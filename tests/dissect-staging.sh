#!/usr/bin/env bash
# Guards harness:dissect-builtin's atomic-publish rule (harness-skills#4,
# PR #40 review, codex BLOCKER).
#
# Step 2 writes both outputs to a staging directory and Step 3 publishes them
# into docs/built-in-skills/<skill-name>/ only once both exist. That is what
# stops a failed re-run of an already-documented skill from destroying the
# previous README.md/PROMPT.md. The rule lives in prose, so this asserts the
# prose still says it — the same shape as the A-CL5 guard in
# gh-pr-skills' tests/pmv-dispatch-resolves.sh.
#
#   sh tests/dissect-staging.sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
SKILL=$ROOT/skills/dissect-builtin/SKILL.md
BRIEF=$ROOT/skills/dissect-builtin/references/readme-template.md
fail=0

# 1. The staging directory is NAMED. "a temp directory" is not actionable: the
#    agent has to be handed a concrete path or it writes to the final one.
grep -qF '.<skill-name>.staging/' "$SKILL" || {
	printf 'FAIL  %s no longer names the staging directory\n' "$SKILL"
	fail=1
}

# 2. Publishing copies the two FILES. Moving the staging DIRECTORY onto an
#    existing output directory nests inside it instead of replacing it.
grep -q '디렉터리째 `mv` 하면' "$SKILL" || {
	printf 'FAIL  %s no longer warns against moving the staging directory itself\n' "$SKILL"
	fail=1
}

# 3. Failure removes staging only, leaving the published outputs untouched.
grep -q '실패 시 — 스테이징만 지운다' "$SKILL" || {
	printf 'FAIL  %s no longer scopes the failure cleanup to staging\n' "$SKILL"
	fail=1
}

# 4. The agent brief must not send the agent straight at the final path, or the
#    staging rule is bypassed by the very agent it exists to contain.
grep -q 'the path Step 2 gives it' "$BRIEF" || {
	printf 'FAIL  %s no longer tells the agent to write where Step 2 says\n' "$BRIEF"
	fail=1
}

# 5. Only ONE agent is launched; the parent writes PROMPT.md itself. The six
#    per-harness mappings have to agree, or a non-Claude harness still spawns
#    two writers (PR #40 review, codex BLOCKER).
for f in "$ROOT"/references/*-tools.md; do
	if grep -qiE 'dissect-builtin.*(two|병렬)|(two|병렬).*dissect-builtin' "$f"; then
		printf 'FAIL  %s still describes the retired two-agent dissect-builtin flow\n' "$f"
		fail=1
	fi
done

if [ "$fail" -eq 0 ]; then
	printf 'ok    dissect-builtin stages both outputs, publishes per-file, and every harness mapping agrees on one agent\n'
fi
exit "$fail"
