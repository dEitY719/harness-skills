---
name: harness-refactor
description: >-
  harness-legacy-check 감사 리포트를 바탕으로 low-risk 하네스 개선 워크플로우를
  생성하고 실행한다. Use when the user runs /harness:harness-refactor,
  "하네스 리팩토링해줘", "하네스 정리해줘", or after reviewing a
  harness-legacy-check report to apply its findings.
license: MIT
metadata:
  model_recommendation:
    tier: sonnet
    reason: "audit report classification + multi-agent workflow orchestration for file edits"
    claude: prefer
    non_claude: advisory-only
---

# harness:harness-refactor

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` verbatim and stop.

## Role

harness-legacy-check 감사 리포트를 읽고 low-risk 항목만 골라
`harness-refactor` 워크플로우에 전달해 실행한다.

어느 단계든 실패하면 즉시 `[FAIL] harness:harness-refactor — <이유>` 출력 후 중단한다.
Step 3 실패 시 이미 아카이브된 파일 경로를 함께 출력한다.

## Step 1: 감사 리포트 확인

`.claude/reports/harness-legacy-check.md` 파일이 있으면 읽어서 사용한다.
없으면: "harness-legacy-check 결과가 없습니다. 먼저 /harness:harness-legacy-check 를
실행해 주세요." 출력 후 중단.

## Step 2: Low-risk 항목 분류

리포트 항목을 워크플로우 포함 여부로 분류해 두 배열로 정리한다.
분류 기준과 각 배열의 형식: `references/classification-rules.md` 참조.

- `changes` — 허용 항목, `{ file, description }`.
- `rejected` — 금지 항목, `{ file, description, reason }`. 워크플로우에는
  적용시키지 않고 Final Report 의 "Human Approval Required" 섹션에만
  기록하도록 전달한다.

## Step 3: 워크플로우 실행

```
Workflow({ name: 'harness:harness-refactor', args: { changes: <Step 2 changes>, rejected: <Step 2 rejected> } })
```

워크플로우 스크립트는 이 플러그인에 함께 배포된다: `workflows/harness-refactor.js`.
매 실행마다 모델이 다시 작성하지 않는다 — 바뀌는 것은 `args.changes` 뿐이다.

`Workflow` 는 Claude Code 전용 도구다. 다른 하네스는 저장소 루트의
`references/<harness>-tools.md` (codex / gemini / hermes / kimi / opencode / antigravity)
에 적힌 대체 절차를 따른다.

## Step 4: 완료 보고

```
[OK] harness:harness-refactor — 완료
  변경 파일: N개  |  생성 references/: N개  |  아카이브: N개
  Human review 필요: N개 (Final Report "Human Approval Required" 참조)
  다음: git diff 확인 후 /gh-pr:commit
```

실패 시: `[FAIL] harness:harness-refactor — <이유>`

---

## 짝을 이루는 스킬 (Related Skills)

- `harness:harness-legacy-check` — 이 스킬의 입력인 감사 리포트를 생성한다.
  먼저 실행해 `.claude/reports/harness-legacy-check.md` 를 만들어 둘 것.
