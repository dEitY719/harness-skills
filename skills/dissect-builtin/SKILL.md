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

**두 산출물 모두 임시 디렉터리에 먼저 쓴다.** 최종 경로에 바로 쓰면 뒤에서
실패했을 때 이미 덮어쓴 기존 문서를 되돌릴 수 없다. 이동은 Step 3 에서 한다.

Write `PROMPT.md` yourself, straight from the Step 1 prompt in context. Do not
delegate it to an agent: a round-trip through another model cannot improve an
exact copy, only corrupt it.

Then read `references/readme-template.md` yourself and launch one Agent to
write `README.md`. A subagent inherits neither this skill's base directory nor
the prompt Step 1 loaded into your context, so put **both** in the Agent's
prompt: the brief you just read, and the raw prompt text itself. Sending the
Agent to find either one leaves it analyzing nothing — a repo-relative path
resolves against the caller's project rather than the installed plugin, and
the prompt exists only in your context.

### Step 3: Confirm with user

Wait for the agent to finish. **두 파일이 모두 임시 디렉터리에 있을 때에만**
`docs/built-in-skills/<skill-name>/` 로 옮기고, 그 뒤 판정을 낸다:

```
[OK] harness:dissect-builtin
  Skill:    <skill-name>
  Outputs:  docs/built-in-skills/<skill-name>/README.md
            docs/built-in-skills/<skill-name>/PROMPT.md
  Next:     /gh-pr:commit
```

실패 시 — 임시 디렉터리를 지우고 끝낸다. 최종 경로는 아직 건드린 적이 없으므로
기존 문서는 자동으로 보존되고, 반쪽짜리 디렉터리도 생기지 않는다:

```
[FAIL] harness:dissect-builtin
  Step:    <Step 1 load | Step 2 agent | Step 2 write>
  Detail:  <error or skill not built-in>
```

## Constraints

- PROMPT.md reproduces the original prompt verbatim: do not summarize, translate, or reformat.
  That is a fidelity target, not a verifiable guarantee — the prompt exists only in context,
  so there is nothing to `cp` or diff against and byte-equality cannot be checked afterwards.
  Fewer hops is the only lever, which is why the parent writes it directly: one hop, not two.
- README.md is written in Korean. Use English only for technical terms.
- Do not use the filename `SKILL.md` for output — it conflicts with Claude Code's skill loading mechanism.
- If the target skill cannot be loaded (not a built-in skill), inform the user and suggest alternatives.
