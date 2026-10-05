---
name: dissect-builtin
description: >-
  Analyze a Claude Code built-in skill and save Korean documentation
  (README.md + PROMPT.md) under docs/built-in-skills/. Use for
  "/harness:dissect-builtin <skill-name>", "내장 스킬 분석", "스킬 해부", or any
  request to study or document a built-in skill.
license: MIT
metadata:
  model_recommendation:
    tier: sonnet
    reason: "structure analysis + Korean documentation generation; moderate reasoning"
    claude: prefer
    non_claude: advisory-only
---

# Dissect Built-in Skill

## Help

If args is `-h`/`--help`/`help`, read `references/help.md` verbatim and stop.

## Usage

`/harness:dissect-builtin <skill-name>`

## Workflow

Run these steps in order. Stop immediately on any error (skill load failure, agent failure, write error): clean up with Step 3's `--abort`, then emit a `[FAIL]` verdict.

### Step 1: Load the skill prompt

Load the target built-in skill with `Skill(skill: "<skill-name>")`.
The raw prompt is injected into your context — that is the source Step 2 copies `PROMPT.md` from.
The `Skill` tool and Claude Code built-ins are Claude-Code-only; other harnesses cannot reach them - see the repo-root `references/*-tools.md`.

### Step 2: Write the two outputs

Outputs: `README.md` (Korean) and `PROMPT.md` (verbatim), published by Step 3 to
`docs/built-in-skills/<skill-name>/` (relative to the project root).

**두 산출물 모두 `docs/built-in-skills/.<skill-name>.staging/` 에 먼저 쓴다**
(에이전트에게도 이 경로를 준다). 최종 경로에 바로 쓰면 실패했을 때 덮어쓴 기존
문서를 되돌릴 수 없다. 이동은 Step 3 에서 한다.

Write `PROMPT.md` yourself, straight from the Step 1 prompt in context. Do not
delegate it to an agent: a round-trip through another model cannot improve an
exact copy, only corrupt it.

Then read `references/readme-template.md` yourself and launch one Agent to write
`README.md`. A subagent inherits neither this skill's base directory nor the
prompt Step 1 loaded, so put **both** in its prompt: the brief you just read and
the raw prompt text. Sending it to find either leaves it analyzing nothing — a
repo-relative path resolves against the caller's project, not the plugin.

### Step 3: Promote + verdict

Wait for the agent, then publish with the bundled script. It promotes only when
**both** files are staged (file by file, never the directory); otherwise it removes
staging and leaves `docs/built-in-skills/<skill-name>/` untouched. On a Step 1/2
failure run it with `--abort` instead (staging removed, nothing published):

```bash
_ps=""
if [ -n "${HERMES_SKILL_DIR}" ]; then _ps="${HERMES_SKILL_DIR}/lib/promote-staging.sh"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then _ps="$CLAUDE_PLUGIN_ROOT/skills/dissect-builtin/lib/promote-staging.sh"
fi
[ -n "$_ps" ] && [ -f "$_ps" ] || { printf '[FAIL] plugin root unresolved (tried: %s). Export HERMES_SKILL_DIR=<this skill dir> (single-skill install) or CLAUDE_PLUGIN_ROOT=<plugin dir> first.\n' "${_ps:-nothing}" >&2; return 1 2>/dev/null || exit 1; }
sh "$_ps" <skill-name> [--abort]
```

Relay its result: `[OK] promoted` →

```
[OK] harness:dissect-builtin
  Skill:    <skill-name>
  Outputs:  docs/built-in-skills/<skill-name>/README.md
            docs/built-in-skills/<skill-name>/PROMPT.md
  Next:     /gh-pr:commit
```

`[FAIL] staging incomplete: missing <file>` (exit 1), or any earlier failure →

```
[FAIL] harness:dissect-builtin
  Step:    <Step 1 load | Step 2 agent | Step 2 write | Step 3 promote>
  Detail:  <error, the script's [FAIL] line, or skill not built-in>
```

## Constraints

- PROMPT.md reproduces the original prompt verbatim: do not summarize, translate, or reformat.
  A fidelity target, not a verifiable guarantee — the prompt exists only in context, so there is
  nothing to diff against. Fewer hops is the only lever: the parent writes it, one hop not two.
- README.md is written in Korean. Use English only for technical terms.
- Do not use the filename `SKILL.md` for output — it conflicts with Claude Code's skill loading mechanism.
- If the target skill cannot be loaded (not a built-in skill), inform the user and suggest alternatives.
