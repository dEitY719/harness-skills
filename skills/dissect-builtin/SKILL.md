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

Analyze a Claude Code built-in skill and produce structured documentation in Korean.

## Usage

```
/harness:dissect-builtin <skill-name>
```

## Workflow

Run these steps in order. Stop immediately on any error (skill load failure, agent failure, write error) and emit a `[FAIL]` verdict.

### Step 1: Load the skill prompt

Use the Skill tool to load the target built-in skill:

```
Skill(skill: "<skill-name>")
```

The raw prompt is injected into your context — that is the source Step 2 copies `PROMPT.md` from.
The `Skill` tool and Claude Code built-ins are Claude-Code-only; other harnesses cannot reach them - see the repo-root `references/*-tools.md`.

### Step 2: Write the two outputs

Output directory: `docs/built-in-skills/<skill-name>/` (relative to the project root).

| Output    | Path                                          | Format    |
|-----------|-----------------------------------------------|-----------|
| README.md | docs/built-in-skills/<skill-name>/README.md | Korean MD |
| PROMPT.md | docs/built-in-skills/<skill-name>/PROMPT.md | Verbatim  |

Write `PROMPT.md` yourself, straight from the Step 1 prompt in context. Do not
delegate it to an agent: a round-trip through another model cannot improve an
exact copy, only corrupt it.

Then read `references/readme-template.md` yourself and launch one Agent to
analyze the loaded prompt and write `README.md`, passing that brief in the
Agent's prompt. Do not send the Agent to find the file: a subagent does not
inherit this skill's base directory, so a repo-relative path resolves against
the caller's project instead of the installed plugin — the same round-trip
this step exists to remove.

### Step 3: Confirm with user

Wait for the agent to finish, then emit a deterministic verdict:

```
[OK] harness:dissect-builtin
  Skill:    <skill-name>
  Outputs:  docs/built-in-skills/<skill-name>/README.md
            docs/built-in-skills/<skill-name>/PROMPT.md
  Next:     /gh-pr:commit
```

실패 시 — **이번 실행이 새로 만든** 산출물만 지워 반쪽짜리 디렉터리를 남기지
않는다. Step 2 를 시작하기 전에 두 출력 경로 각각이 이미 있었는지 확인해 두고,
없던 것만 지운다. 같은 `<skill-name>` 을 다시 문서화하는 실행이 실패했다고 해서
먼저 있던 문서를 지우면 안 된다:

```
[FAIL] harness:dissect-builtin
  Step:    <Step 1 load | Step 2 agent | Step 2 write>
  Detail:  <error or skill not built-in>
```

## Constraints

- PROMPT.md must be an exact copy of the original prompt. Do not summarize, translate, or reformat.
  The prompt exists only in context — there is no on-disk original to `cp` — so the copy is
  model-mediated by construction. That is why it goes through one model hop, not two.
- README.md is written in Korean. Use English only for technical terms.
- Do not use the filename `SKILL.md` for output — it conflicts with Claude Code's skill loading mechanism.
- If the target skill cannot be loaded (not a built-in skill), inform the user and suggest alternatives.
