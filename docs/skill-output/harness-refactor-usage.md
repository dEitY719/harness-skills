# harness-refactor 사용 결과

> **한 줄 요약** — 감사 리포트를 받아 low-risk 항목만 담은 워크플로우 파일 1개를 생성하고 실행해 하네스를 정리합니다.

> NOTE: **미실행 예시** — 이 스킬은 워크플로를 생성해 실행하고 사용자 하네스를 실제로 변경하므로 문서화 목적으로 실행하지 않았습니다. 명령·분류 규칙·출력 형식은 skills/harness-refactor/SKILL.md 인용이며 실행 로그가 아닙니다.

```
harness-legacy-check 리포트  ──▶  /harness:harness-refactor  ──▶  harness-refactor.js 생성 + 실행
```

## 1. 실행할 명령

```
/harness:harness-refactor      # 인자 없음 — 리포트 경로는 고정 탐색 순서로 결정
/harness:harness-refactor -h   # references/help.md 출력 후 중단
```

## 2. 입력

- **감사 리포트** — `.claude/reports/harness-legacy-check.md`. 없으면 현재 세션의 `harness-legacy-check` 출력에서 찾는다.
- **분류 기준** — `references/classification-rules.md`. 리포트 항목을 워크플로우에 넣을
  허용 변경과, 넣지 않고 사람에게 넘길 금지 항목으로 가른다.
- **선행 조건(게이트):** 리포트를 두 경로 모두에서 찾지 못하면 "harness-legacy-check 결과가
  없습니다. 먼저 /harness-legacy-check 를 실행해 주세요." 를 출력하고 중단한다 — 감사를
  대신 수행하지 않는다.

## 3. 결과 (실행 시)

- **`.claude/workflows/harness-refactor.js`** — 새로 작성되며 이전 파일을 덮어쓴다(이전 계획은
  git log 에 보존). `export const meta` 가 Pre-flight → Apply Changes → Verify → Final Report
  4개 phase 를 선언하고 `ARCHIVE` / `SKILLS` / `ROOT` 상수를 정의한다.
- **워크플로우 실행** — `Workflow({ scriptPath: '.claude/workflows/harness-refactor.js' })`.
  Pre-flight 는 대상 파일 존재 확인과 archive 디렉토리 생성만, Apply Changes 는 `parallel()`
  로 비중첩 파일 그룹별 에이전트, Verify 는 `wc -l` 비교와 `references/` 생성 확인.
- **아카이브** — 삭제 대상은 영구 삭제 없이 `.claude/archive/harness-refactor-YYYY-MM-DD/` 로 이동.
- **Final Report** — 변경 목록·이유·behavior delta·smoke-test 5개, 그리고 금지로 분류된 항목만
  모은 **"Human Approval Required"** 섹션. hooks·MCP·권한 확대·앱 코드 수정·테스트/빌드/배포
  실행·신뢰도 low 항목은 여기에만 기록되고 자동 적용되지 않는다.
- **완료 보고** — `[OK] harness:harness-refactor — 완료` 와 변경 파일 / 생성 references /
  아카이브 / human review 건수, 다음은 `git diff` 확인 후 `/gh-pr:commit`. 실패 시 `[FAIL] ... — <이유>`.
