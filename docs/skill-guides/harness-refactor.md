# harness-refactor — 감사 리포트 기반 low-risk 개선 적용

**한 줄 요약** — `harness-legacy-check` 감사 리포트를 읽어 low-risk 항목만
골라 `claude/workflows/harness-refactor.js` 를 새로 산출하고, 그 워크플로우를
실행해 실제 하네스 파일 변경을 만들어 낸다.

## 언제 쓰고 언제 안 쓰는가

| 상황 | 사용 여부 |
|------|-----------|
| 감사 리포트를 검토했고 이제 안전한 항목을 적용하고 싶다 | 사용 |
| 아직 감사를 돌리지 않았다 | 사용 금지 — 먼저 `harness:harness-legacy-check` |
| 무엇이 문제인지 보기만 하고 싶다 | 사용 금지 — `harness:harness-legacy-check` |
| 컨텍스트 문서 하나를 분할하고 싶다 | 사용 금지 — `harness:ai-context refactor` |

`harness-legacy-check` 가 **읽기 전용**인 반면 이 스킬은 **쓰기**다. 둘은
한 쌍으로 설계됐고, 리포트 파일이 둘 사이의 인터페이스다.

## 호출 형식

```
/harness:harness-refactor
/harness:harness-refactor -h
```

인자는 없다. 첫 인자가 `-h` / `--help` / `help` 이면
`references/help.md` 를 그대로 출력하고 중단한다.

## 동작 단계

1. **감사 리포트 확인** — 다음 순서로 찾는다.
   1. `.claude/reports/harness-legacy-check.md` 파일
   2. 현재 세션의 harness-legacy-check 출력
   3. 둘 다 없으면 "먼저 실행해 주세요" 안내 후 **중단** (가드 경로)
2. **low-risk 분류** — `references/classification-rules.md` 기준으로 각 항목을
   워크플로우에 포함할지 판단한다.
3. **워크플로우 생성** — `claude/workflows/harness-refactor.js` 를 새로 쓴다.
   구조와 설계 원칙은 `references/workflow-template.md` 를 따른다. 이전 파일은
   덮어쓰기되며, 이전 계획은 git log 에 보존된다.
4. **워크플로우 실행** — `Workflow({ scriptPath: 'claude/workflows/harness-refactor.js' })`
5. **완료 보고** — 변경 파일 수, 생성한 `references/` 수, 아카이브 수,
   human review 필요 건수와 함께 `[OK]` 를 출력한다.

## 주의사항 / 제약

- **실제로 하네스 파일을 변경한다.** 실행 전에 작업 트리가 깨끗한지 확인하고,
  실행 후에는 `git diff` 로 검토한 뒤 커밋하는 것이 전제다.
- 위험하다고 분류된 항목은 자동 적용하지 않고 Final Report 의
  "Human Approval Required" 섹션에만 기록된다.
- 감사 리포트가 없으면 아무것도 하지 않고 멈춘다 — 이것이 정상 동작이다.
- 이전 `harness-refactor.js` 는 병합하지 않고 통째로 덮어쓴다.
- Claude Code 의 `Workflow` 도구에 의존한다. 다른 하네스에서는
  `references/*-tools.md` 의 대체 경로를 따른다.
