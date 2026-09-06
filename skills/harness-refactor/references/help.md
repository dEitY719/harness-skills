# harness:harness-refactor — Help

## Usage

/harness:harness-refactor

harness-legacy-check 감사 리포트를 바탕으로 low-risk 하네스 개선을 적용하는
워크플로우를 실행한다.

## 사전 조건

`.claude/reports/harness-legacy-check.md` 파일이 있어야 한다.
없으면 스킬이 중단하고 `/harness:harness-legacy-check` 를 먼저 실행할 것을 안내한다.

## 실행 흐름

1. `.claude/reports/harness-legacy-check.md` 리포트 확인
2. low-risk 항목 분류 (references/classification-rules.md 기준)
3. `Workflow({ name: 'harness:harness-refactor', args: { changes: [...], rejected: [...] } })` 실행
4. [OK]/[FAIL] 결과 요약 보고

## 결과

워크플로우 스크립트(`workflows/harness-refactor.js`)는 이 플러그인에 이미
배포되어 있고 매 실행마다 다시 작성되지 않는다. 바뀌는 것은 분류된 변경
목록(`args.changes`, `args.rejected`)뿐이며, `changes` 가 실제로 적용할
low-risk 변경을, `rejected` 가 Final Report 의 "Human Approval Required"
섹션에 기록될 금지 항목을 정한다.
