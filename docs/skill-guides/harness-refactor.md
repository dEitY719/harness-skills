# harness-refactor

> 한 줄 요약 — `harness-legacy-check` 감사 리포트를 읽어 항목을 risk 로 분류한 뒤, low-risk 항목만 담은 **`.claude/workflows/harness-refactor.js` 워크플로우 파일 1개**를 새로 작성해 실행한다. 위험한 항목은 실행하지 않고 Final Report 의 "Human Approval Required" 섹션에만 남긴다. 읽기 전용이 아니라 **실제로 하네스 파일을 고친다**.

## 언제 쓰고 언제 안 쓰는가

**쓸 때** — `/harness:harness-legacy-check` 를 이미 돌려 감사 리포트를 받았고, 그 리포트가
지적한 것 중 안전하게 자동화할 수 있는 부분을 실제로 적용하려 할 때. CLAUDE.md/AGENTS.md 의
중복 섹션 정리, 전역 지침에 눌러앉은 절차를 skill 로 이관, 비대해진 SKILL.md 를
`SKILL.md + references/` 로 분리, description/trigger 문구 정리, settings.json 의 stale 권한
제거 같은 작업이 여기 해당한다.

**안 쓸 때 — 경계:**

- **감사 자체가 아직 없다면 `/harness:harness-legacy-check` 가 먼저다.** 이 스킬은 감사를
  대신 수행하지 않는다. 리포트를 못 찾으면 Step 1 에서 그냥 중단한다.
- **읽기만 하고 싶다면 이 스킬이 아니다.** `harness-legacy-check` 는 어떤 파일도 건드리지
  않는 read-only 감사지만, 이 스킬은 워크플로우를 생성하고 그 워크플로우가 파일을 옮기고
  고친다. "뭐가 문제인지만 보고 싶다" 는 요구에는 짝 스킬을 쓴다.
- **hooks·MCP·권한 확대·애플리케이션 코드**를 고치고 싶다면 이 스킬로는 안 된다. 분류
  규칙이 이들을 영구 금지 목록에 두고 있어, 리포트에 있어도 워크플로우에 절대 들어가지
  않는다. 사람이 직접 판단하고 직접 고쳐야 한다.
- `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` 문서 하나를 점검하거나 새로 만드는 일은
  `harness:ai-context` 의 몫이다.

이 check / refactor 분리는 의도된 것이다. 감사는 아무것도 안 바꾸므로 마음 놓고 자주 돌릴
수 있고, 변경은 사람이 리포트를 읽고 납득한 뒤에만 별도 호출로 일어난다.

## 호출 형식

```
/harness:harness-refactor
/harness:harness-refactor -h | --help | help
```

인자를 받지 않는 스킬이다. 대상 리포트도, 적용 범위도 위치 인자로 지정하지 않는다.

| 인자 | 기본값 | 설명 |
|------|--------|------|
| (없음) | — | 리포트 경로는 고정 탐색 순서로 결정된다(아래 Step 1). 사용자가 지정하지 않는다 |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 중단. 파일 변경 없음 |

## 동작 단계

1. **Step 1 — 감사 리포트 확인.** 고정된 순서로 찾는다: (1) `.claude/reports/harness-legacy-check.md`
   파일이 있으면 읽어서 사용, (2) 없으면 현재 세션에 남은 `harness-legacy-check` 출력을 찾는다,
   (3) 둘 다 없으면 "harness-legacy-check 결과가 없습니다. 먼저 /harness-legacy-check 를
   실행해 주세요." 를 출력하고 **중단한다**. 리포트를 지어내거나 감사를 즉석에서 대신 하지
   않는다.
2. **Step 2 — risk 분류.** 리포트의 각 항목을 `references/classification-rules.md` 기준으로
   워크플로우에 넣을 것(허용 변경)과 넣지 않을 것(절대 금지)으로 가른다. 이 분류가 이 스킬의
   안전 계약 전부다 — 아래 "주의사항과 제약" 에 두 목록을 그대로 옮겨 둔다.
3. **Step 3 — `harness-refactor.js` 생성.** `.claude/workflows/harness-refactor.js` 를 **새로**
   작성한다. 이전 파일은 덮어쓴다(이전 계획은 git log 에 남는다). 파일 구조는
   `references/workflow-template.md` 가 규정한다: `export const meta` 에 4개 phase
   (Pre-flight → Apply Changes → Verify → Final Report), `ARCHIVE` / `SKILLS` / `ROOT`
   상수, 아카이브 경로의 `YYYY-MM-DD` 는 오늘 날짜로 고정. Step 2 에서 금지로 분류된 항목은
   워크플로우 본문이 아니라 Final Report 의 "Human Approval Required" 섹션에만 기록한다.
4. **Step 4 — 워크플로우 실행.** `Workflow({ scriptPath: '.claude/workflows/harness-refactor.js' })`.
   Pre-flight 가 대상 파일 존재 확인과 archive 디렉토리 생성만 하고(파일 수정 없음), Apply
   Changes 가 `parallel()` 로 비중첩 파일 그룹을 나눠 맡은 에이전트들을 돌리며, 각 에이전트는
   아카이브 후 수정하고 `CHANGE_SCHEMA` 로 구조화된 결과를 돌려준다. Verify 가 `wc -l` 비교와
   `references/` 파일 생성 여부를 확인한다.
5. **Step 5 — 완료 보고.** `[OK] harness:harness-refactor — 완료` 아래에 변경 파일 수,
   생성된 `references/` 수, 아카이브 수, human review 필요 항목 수, 그리고 다음 행동
   (`git diff` 확인 후 `/gh-pr:commit`)을 적는다. 실패 시
   `[FAIL] harness:harness-refactor — <이유>`.

## 주의사항과 제약

**이 스킬은 파일을 바꾼다.** 짝 스킬과 헷갈리기 쉬운 지점이다. `harness-legacy-check` 는
read-only 이지만 `harness-refactor` 는 워크플로우 스크립트를 새로 쓰고, 그 워크플로우가
CLAUDE.md/AGENTS.md/SKILL.md/settings.json 을 실제로 수정한다. 호출 전에 작업 트리가 깨끗한지
확인하고, 호출 후에는 `git diff` 를 사람이 읽는 것이 전제다.

**허용 변경 (워크플로우에 포함)** — CLAUDE.md/AGENTS.md 의 중복·일반론 섹션 제거, 특정 작업
절차를 전역 지침에서 skill 로 이동, 긴 SKILL.md 를 `SKILL.md + references/` 구조로 분리,
skill description/trigger 명확화, settings.json 의 stale 권한 항목 제거.

**절대 금지 (Human Approval Required 목록으로만 기록)** — hooks 수정, MCP 설정 변경,
allowed-tools 권한 확대, 프로젝트 애플리케이션 코드 수정, 테스트·빌드·배포 명령 실행,
그리고 리포트가 신뢰도 **low** 로 표시한 모든 항목. 리포트가 아무리 강하게 권해도 이 여섯은
워크플로우에 들어가지 않는다. 자동 적용과 사람 판단 사이의 선이 여기다.

**삭제는 영구 삭제가 아니다.** 제거 대상은 지우는 대신
`.claude/archive/harness-refactor-YYYY-MM-DD/` 로 옮긴다. 잘못 판단한 삭제를 되돌릴 수 있게
하려는 것이므로, 워크플로우를 손볼 때도 이 아카이브 단계를 건너뛰지 않는다.

**이전 워크플로우 파일은 덮어써진다.** `.claude/workflows/harness-refactor.js` 는 매 호출마다
새로 생성된다. 손으로 고친 내용이 그 파일에 있다면 호출 전에 커밋해 두어야 git log 로만이라도
남는다.

**중단 조건** — 감사 리포트를 어느 경로로도 찾지 못하면 아무것도 하지 않고 멈춘다. 이때
스킬은 감사를 대신 실행하지 않으며, `/harness-legacy-check` 를 먼저 돌리라고만 안내한다.

**하네스 의존성** — Step 4 는 Claude Code 의 `Workflow` 도구를, 병렬 적용은 서브에이전트
오케스트레이션을 전제한다. 다른 하네스에서는 해당 기능의 대응 도구를 `references/*-tools.md`
매핑에서 찾아야 하고, metadata 상 non-Claude 하네스에서는 advisory-only 다.
