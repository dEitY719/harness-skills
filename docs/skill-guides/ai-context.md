# ai-context

> 한 줄 요약 — `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` 한 개를 대상으로, 업계 기준(Codex / Claude Code / Gemini CLI 스펙) 대비 **PASS/WARN/FAIL 판정표와 `[OK]` 또는 `[FAIL]` 판정이 붙은 리포트 1건**을 산출한다. `create` / `refactor` 로 부르면 리포트에 더해 컨텍스트 파일 자체를 쓴다 — 다만 쓰기 전에 항상 사용자 확인을 받는다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때** — 대상이 **AI 컨텍스트 주입 파일**일 때. 즉 세션 시작 시 모델 컨텍스트로
자동 로드되는 `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` 세 종류다. 이미 있는 파일이
기준에 맞는지 감사하려면 `check`(기본값), 없는 파일을 프로젝트 규모에 맞는
템플릿에서 새로 만들려면 `create`, 비대해진 파일을 중첩 파일로 쪼개려면 `refactor`.

**안 쓸 때 — 형제 스킬로 가는 경계:**

- **`SKILL.md` 는 이 스킬의 소관이 아니다 — `skill:check` 로 간다.** SKILL.md 도
  마크다운이고 프런트매터가 있어 헷갈리기 쉽지만, 로딩 모델(스킬 트리거 기반)과
  검사 항목(16개 구조·UX·보안 항목)이 완전히 다르다. Stop condition 에 명시된
  라우팅이라 이 스킬은 대상이 `SKILL.md` 면 실행하지 않고 안내만 하고 멈춘다.
- **`*.sh` 는 `sh:check` 로 간다.** 마찬가지로 명시적 라우팅 정지 조건이다.
- 같은 저장소의 **`harness-legacy-check`** 는 한 파일이 아니라 **하네스 전체**
  (컨텍스트 문서 + 스킬 + 워크플로 + settings + 훅 + MCP)를 훑어
  `.claude/reports/harness-legacy-check.md` 로 리포트를 남기는 read-only 감사다.
  컨텍스트 문서 한 개만 깊게 보는 것이 `ai-context check`, 하네스 전반을 넓게
  보는 것이 `harness-legacy-check` 다.
- **`harness-refactor`** 는 그 하네스 리포트를 읽어 저위험 항목을 실제로 고치는
  쪽이다. 이름이 비슷한 `ai-context refactor` 와는 대상이 다르다 — 후자는
  **컨텍스트 파일 한 개**를 중첩 파일로 분할하는 일만 한다.

이 스킬은 삭제된 다섯 개 레거시 스킬(`agents-md:{check,create,refactor}`,
`claude-md-check`, `claude-md-create`)의 단일 진입점이다. 옛 명령을 찾고 있다면
`references/help.md` 의 마이그레이션 표를 보면 된다.

## 호출 형식

```
/harness:ai-context [action] [path]
/harness:ai-context [action] [--file PATH] [--type TYPE]
/harness:ai-context -h | --help | help
```

`references/help.md` 가 1차 근거다. 위치 인자는 `[action] [path]` 순이며,
알 수 없는 action 이 오면 help 를 출력하고 멈춘다.

| 인자 / 플래그 | 기본값 | 설명 |
|---------------|--------|------|
| `action` | `check` | `check` / `create` / `refactor` / `help` 중 하나 |
| `path` | 자동 탐지 | 대상 파일 경로를 직접 지정 |
| `--file PATH` | — | 위치 인자 `path` 와 같되 **우선한다** |
| `--type TYPE` | 파일명에서 유추 | 어댑터 강제: `agents` / `claude` / `gemini` |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 중단 |

자동 탐지 우선순위는 cwd 기준 `CLAUDE.md` → `AGENTS.md` → `GEMINI.md` 다.
파일명 → 타입 매핑은 `CLAUDE.md`→claude, `AGENTS.md`→agents, `GEMINI.md`→gemini
이고, 비표준 파일명은 `--type` 으로 덮어쓴다.

예시:

- `/harness:ai-context` — 자동 탐지 후 check. 컨텍스트 파일이 하나뿐일 때만 권장
- `/harness:ai-context check AGENTS.md` — `CLAUDE.md` 도 있는 저장소에서 대상 명시
- `/harness:ai-context check --file ./docs/AGENTS.md` — 루트가 아닌 경로 감사
- `/harness:ai-context create --type agents` — 새 AGENTS.md 작성 흐름
- `/harness:ai-context refactor` — 분할 계획을 제시하고, 확인받은 뒤 실행

## 동작 단계

1. **Step 1 — 인자 파싱.** `$1` 이 `-h` / `--help` / `help` 면 `references/help.md`
   를 그대로 출력하고 즉시 멈춘다. 이때는 다른 파일을 전혀 읽지 않는다.
2. **Step 2 — 대상 파일 결정.** `--file`(또는 위치 인자)이 있으면 그것을 쓰고,
   없으면 우선순위대로 자동 탐지한다. 파일이 여러 개면 `check` 는 최상위 우선순위
   파일만 감사하고 나머지는 WARN 으로 남기며, `create` / `refactor` 는 후보를
   출력하고 사용자에게 묻는다 — **자동으로 고르지 않는다.** 파일이 하나도 없으면
   `check` / `refactor` 는 `harness:ai-context create` 를 힌트로 주고 중단한다.
3. **Step 3 — 액션별 분기.**
   - **`check` (read-only)** — `references/checks.md` 의 **코어 검사 C1~C7**
     (Role/Purpose, Operational Commands, Loading & Scope Model, Modular
     References, Naming Conventions, Constraints, Size)에 더해 타입별 **어댑터
     검사**를 돌린다: `agents` → A-AG1~4(Discovery, Override, Payload budget,
     Context Map), `claude` → A-CL1~4(Reference-by-path, Permission Control,
     Thin Orchestrator, Local+rules layout), `gemini` → A-GE1~3(Hierarchy,
     `/memory`·imports, `.geminiignore`). 각 판정에는 근거가 된 라인을 인용한다.
     파일은 절대 건드리지 않는다.
   - **`create` (확인 후 쓰기)** — Phase 0 디스커버리로 규모를 분류한다.
     `agents` 는 프로젝트 크기(small <20 파일 / medium 20~100 / large 100+),
     `claude` 는 에이전트 수(simple 1~2 / standard 3~6 / large 7+) 기준이다.
     `gemini` 는 아직 템플릿이 없어 가장 가까운 agents 템플릿을 수동 편집
     힌트와 함께 제안한다. `references/templates/` 에서 템플릿을 읽어 채우고,
     **계획을 제시해 확인을 받은 뒤에야** 쓴다.
   - **`refactor` (확인 후 쓰기)** — 기존 파일을 읽어 중첩 파일로 옮겨야 할
     인라인 블록·섹션을 목록화하고, 분할 계획을 제시해 **확인을 받은 뒤**
     섹션을 추출하고 루트 파일을 얇게 만든다.
4. **Step 4 — 리포트.** 액션이 무엇이든 `references/report-template.md` 형식으로
   출력한다. 헤더(File / Kind / Baseline 스냅샷 날짜), 검사 결과 표, `Verdict`,
   WARN·FAIL 만 담는 `Issues & Improvements`, 그리고 마지막의 `Next:` 줄이다.
   FAIL 이 하나도 없으면 `[OK]`, 하나라도 있으면 `[FAIL]` 이다. WARN 만 있으면
   `[OK]` 이되 경고 개수를 표면에 드러낸다. `N/A` 는 집계에서 제외한다.

## 주의사항과 제약

**절대 하지 않는 것 (안전 계약)**

- **`check` 는 감사 전용이다.** 어떤 경우에도 대상 파일을 수정하지 않는다.
- **`create` / `refactor` 는 덮어쓰기 전에 항상 확인을 받는다.** 계획을 먼저
  제시하고, 사용자가 동의하기 전에는 쓰지 않는다.
- **컨텍스트 파일이 여러 개일 때 자동 덮어쓰기는 절대 허용되지 않는다.**
  `CLAUDE.md` 와 `AGENTS.md` 가 공존하는 흔한 상황에서, 어느 쪽을 손댈지는
  기계가 아니라 사람이 정한다.
- **`SKILL.md` 와 `*.sh` 에는 실행하지 않는다.** 각각 `skill:check` / `sh:check`
  로 라우팅하고 멈춘다.
- `--file` / `--type` 오버라이드는 자동 탐지보다 항상 우선한다.

**멈추는 조건** — 대상 파일이 없는데 action 이 `check`/`refactor` 인 경우, 파일이
여러 개인데 action 이 `create`/`refactor` 인 경우, 대상을 읽을 수 없는 경우
(원인 에러와 함께 중단), 그리고 위의 두 라우팅 조건이다. Step 1~3 이 라우팅 정지나
help 출력이 **아닌** 진짜 이유로 실패하면 리포트 템플릿에 `Verdict=[FAIL]` 로
기록하고 멈춘다 — 조용히 넘어가지 않는다.

**근거의 출처** — 어댑터 검사의 판정 근거는 지어내지 않고
`references/industry-baseline.md` 를 인용한다. 이 파일은 Codex / Claude Code /
Gemini CLI 공식 문서의 스냅샷이고 **스냅샷 날짜**를 함께 들고 있다(현재
2026-05-11). 리포트 헤더의 `Baseline:` 이 그 날짜를 그대로 노출하므로, 독자는
어떤 시점의 스펙으로 판정됐는지 되짚을 수 있다. 원문 스펙이 바뀌면
`industry-baseline.md` 를 갱신하고 날짜를 올리는 것이 유지보수 경로다.

**자동 탐지의 함정** — 우선순위가 `CLAUDE.md` 부터라서, `AGENTS.md` 를 감사하려는
저장소에 `CLAUDE.md` 가 함께 있으면 인자 없는 호출은 `CLAUDE.md` 를 잡는다.
`AGENTS.md` 가 `CLAUDE.md` 를 가리키는 심볼릭 링크인 흔한 배치에서는 결과가
같아 보이지만, 그때도 리포트의 `Kind:` 는 달라진다(agents 어댑터 vs claude
어댑터). 어느 파일을 어느 어댑터로 볼지 확정하고 싶으면 경로를 명시하라.
