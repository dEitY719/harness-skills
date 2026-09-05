---
name: harness-legacy-check
description: >-
  AI 코딩 하네스(CLAUDE.md, AGENTS.md, skills, workflows, settings, hooks,
  MCP)를 읽기 전용으로 감사해 리포트를 저장한다. Use when the user runs
  /harness:harness-legacy-check, "하네스 감사해줘", "harness check 해줘", or
  before running harness:harness-refactor.
license: MIT
metadata:
  model_recommendation:
    tier: haiku
    reason: "skill itself is a single Workflow() call + completion report; analysis is inside the workflow's own agents"
    claude: prefer
    non_claude: advisory-only
---

# harness:harness-legacy-check

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` verbatim and stop.

## Role

`harness-legacy-check` 워크플로우를 실행해 하네스 전체를 감사하고
결과를 `.claude/reports/harness-legacy-check.md`에 저장한다.
어떤 파일도 수정하거나 삭제하지 않는다.

## Step 1: 워크플로우 실행

```
Workflow({ name: 'harness:harness-legacy-check' })
```

워크플로우 스크립트는 이 플러그인에 함께 배포된다: `workflows/harness-legacy-check.js`.
`Workflow` 는 Claude Code 전용 도구다. 다른 하네스는 저장소 루트의
`references/<harness>-tools.md` (codex / gemini / hermes / kimi / opencode / antigravity)
에 적힌 대체 절차를 따른다.

워크플로우가 완료되면 `.claude/reports/harness-legacy-check.md`에
리포트가 저장된다. 실패 시 즉시 `[FAIL] harness:harness-legacy-check — <이유>` 출력 후 중단.

## Step 2: 완료 보고

```
[OK] harness:harness-legacy-check — 완료
  리포트: .claude/reports/harness-legacy-check.md
  다음: /harness:harness-refactor 로 low-risk 개선 적용
```

실패 시: `[FAIL] harness:harness-legacy-check — <이유>`

---

## 짝을 이루는 스킬 (Related Skills)

이 스킬은 `harness:harness-refactor`와 함께 사용한다. 저장된 리포트
(`.claude/reports/harness-legacy-check.md`)가 그대로 refactor 스킬의 입력이 된다:

1. `/harness:harness-legacy-check` — 감사 실행 + 리포트 저장
2. `/harness:harness-refactor` — 리포트 읽고 low-risk 개선 적용
