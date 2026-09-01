# ai-context — AI 컨텍스트 문서 디스패처

**한 줄 요약** — `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` 한 개를 대상으로,
감사 리포트(check) 또는 새 컨텍스트 문서(create) 또는 분할된 중첩 문서
구조(refactor)를 산출한다.

## 언제 쓰고 언제 안 쓰는가

| 상황 | 사용 여부 |
|------|-----------|
| `AGENTS.md` 가 업계 기준에 맞는지 점검 | 사용 (`check`) |
| 새 프로젝트에 컨텍스트 문서를 처음 만든다 | 사용 (`create`) |
| 비대해진 `CLAUDE.md` 를 중첩 파일로 쪼갠다 | 사용 (`refactor`) |
| `SKILL.md` 를 점검한다 | 사용 금지 — `skill:check` 로 라우팅 |
| `*.sh` 를 점검한다 | 사용 금지 — `sh:check` 로 라우팅 |
| 저장소 디렉터리 구조를 점검한다 | 사용 금지 — `packaging:structure-check` |

형제 스킬과의 경계가 SKILL.md Constraints 에 명시돼 있다. 이 스킬은 문서
"내용" 만 다루며 파일 배치나 셸 품질은 대상이 아니다.

## 호출 형식

```
/harness:ai-context [action] [path] [--file PATH] [--type TYPE] [-h]
```

| 인자 / 플래그 | 설명 | 기본값 |
|---------------|------|--------|
| `action` | `check` / `create` / `refactor` / `help` | `check` |
| `path` | 대상 파일 경로 | 자동 탐지 |
| `--file PATH` | 위 `path` 와 동일, 우선순위 높음 | — |
| `--type TYPE` | 어댑터 강제: `agents` / `claude` / `gemini` | 파일명에서 유추 |
| `-h`, `--help` | `references/help.md` 를 그대로 출력하고 중단 | — |

## 동작 단계

1. **인자 파싱** — 알 수 없는 action 이면 help 를 출력하고 중단.
2. **대상 파일 결정** — `--file` 이 없으면 cwd 에서 `CLAUDE.md` → `AGENTS.md`
   → `GEMINI.md` 우선순위로 자동 탐지. 여러 개가 발견되면 최우선 파일을
   감사하고 나머지는 WARN 으로 보고한다. 자동 덮어쓰기는 절대 하지 않는다.
3. **액션 디스패치**
   - `check` — `references/checks.md` 의 **core 체크(C1-C7) + 어댑터 체크**
     를 실행. 판정 근거가 된 줄을 인용한다. 파일을 변경하지 않는다.
   - `create` — 프로젝트 규모를 분류해 `references/templates/` 에서 맞는
     템플릿을 고르고, 계획을 제시한 뒤 **확인을 받고** 쓴다.
   - `refactor` — 중첩 파일로 옮길 섹션 목록을 분할 계획으로 제시하고,
     **확인을 받고** 추출한다.
4. **리포트** — `references/report-template.md` 형식. FAIL 이 하나도 없으면
   `[OK]`, 있으면 `[FAIL]`. 항상 `Next:` 줄로 끝난다.

## 체크 항목 구성

- **Core (C1-C7)** — 역할/목적, 실행 명령, 로딩·스코프 모델, 모듈화 참조,
  명명 규칙, 제약 규칙, 크기 예산(루트 400줄 이하 PASS).
- **어댑터** — 파일 종류에 따라 추가로 실행된다. `claude` 는 A-CL1 경로 참조,
  A-CL2 권한 통제, A-CL3 얇은 오케스트레이터, A-CL4 로컬·rules 레이아웃.
  `agents` 는 A-AG1-4, `gemini` 는 A-GE1-3.
- 판정 근거는 `references/industry-baseline.md`(스냅샷 2026-05-11)의 Codex /
  Claude Code / Gemini CLI 공식 문서 인용에 연결된다.

## 주의사항 / 제약

- `check` 는 감사 전용이다 — 어떤 경우에도 파일을 변경하지 않는다.
- `create` / `refactor` 는 덮어쓰기 전에 **반드시** 확인을 받는다.
- 컨텍스트 파일이 여러 개 존재할 때 자동 덮어쓰기는 허용되지 않는다.
- `N/A` 판정은 pass/fail 집계에 포함되지 않는다.
- Step 1-3 이 실패하면 (help 출력이나 `skill:check` / `sh:check` 라우팅
  중단은 제외) `[FAIL]` 리포트를 내고 멈춘다.
