# harness-legacy-check — 하네스 읽기 전용 감사

**한 줄 요약** — AI 코딩 하네스 전체(CLAUDE.md, AGENTS.md, skills, workflows,
settings, hooks, MCP)를 읽기 전용으로 감사해
`.claude/reports/harness-legacy-check.md` 리포트 파일 하나를 산출한다.

## 언제 쓰고 언제 안 쓰는가

| 상황 | 사용 여부 |
|------|-----------|
| 하네스 전반에 쌓인 legacy 규칙·중복·비대화를 훑고 싶다 | 사용 |
| `harness:harness-refactor` 를 돌리기 직전 | 사용 (입력을 만든다) |
| 감사 결과를 **적용**하고 싶다 | 사용 금지 — `harness:harness-refactor` |
| 컨텍스트 문서 한 개만 점검하고 싶다 | 사용 금지 — `harness:ai-context check` |
| 저장소 디렉터리 구조만 본다 | 사용 금지 — `packaging:structure-check` |

`ai-context check` 가 문서 **한 개**를 보는 데 비해, 이 스킬은 하네스
**전체**를 본다. 둘 다 읽기 전용이라는 점은 같다.

## 호출 형식

```
/harness:harness-legacy-check
/harness:harness-legacy-check -h
```

인자는 없다. 첫 인자가 `-h` / `--help` / `help` 이면
`references/help.md` 를 그대로 출력하고 중단한다.

## 동작 단계

1. **워크플로우 실행** — `Workflow({ name: 'harness-legacy-check' })` 한 번을
   호출한다. 스킬 자체는 이 호출과 완료 보고가 전부이고, 실제 분석은
   워크플로우 안의 에이전트들이 수행한다.
2. **리포트 저장** — 완료되면 `.claude/reports/harness-legacy-check.md` 에
   리포트가 저장된다(덮어쓰기).
3. **완료 보고** — `[OK] harness:harness-legacy-check — 완료` 와 리포트 경로,
   다음 단계(`/harness:harness-refactor`)를 출력한다. 실패 시
   `[FAIL] harness:harness-legacy-check — <이유>` 를 출력하고 즉시 중단한다.

워크플로우가 수행하는 5개 phase 는 Inventory → Parallel Analysis(5개 specialist
agent 병렬) → Refactor Planner(KEEP / SHRINK / MOVE / SPLIT / CONVERT / DELETE
분류) → Adversarial Review(잘라내면 무엇이 깨지는지 반박) → Final Report 이다.

## 주의사항 / 제약

- **파일을 수정하거나 삭제하지 않는다.** 유일한 쓰기는 리포트 파일 생성이다.
- 리포트는 매 실행마다 덮어쓰기된다 — 이전 리포트를 보존하려면 실행 전에
  따로 복사해 두어야 한다.
- 이 스킬은 Claude Code 의 `Workflow` 도구에 의존한다. 실행되지 않으면
  `/config` 에서 `Dynamic workflows` 와 `Ultracode keyword trigger` 가 모두
  `true` 인지 확인한다. 다른 하네스에서는 `references/*-tools.md` 의 대체
  경로를 따른다.
- 워크플로우는 다수의 에이전트를 띄운다 — 토큰 비용이 작지 않다.
- `harness:harness-refactor` 와 짝이다. 저장된 리포트가 그대로 refactor 의
  입력이 된다.
