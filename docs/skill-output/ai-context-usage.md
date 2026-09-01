# ai-context 사용 결과

> **한 줄 요약** — 컨텍스트 문서 한 개(`CLAUDE.md`)를 받아 core + 어댑터 체크
> 감사 리포트를 생성합니다.

```
CLAUDE.md  ──▶  /harness:ai-context check  ──▶  감사 리포트 (읽기 전용)
```

## 1. 실행한 명령

```
/harness:ai-context [check|create|refactor] [path]      # 범용 형식
/harness:ai-context check CLAUDE.md                     # 이번에 실행한 명령
```

## 2. 입력

`CLAUDE.md` — 이 저장소의 기여자 가이드라인 겸 AI 컨텍스트 문서.
106줄 / 5,297 bytes. `AGENTS.md` 는 이 파일을 가리키는 심볼릭 링크이고,
`GEMINI.md`(3,116 bytes)는 별도 파일로 함께 존재한다.

## 3. 결과

```
## harness:ai-context — check
File:     CLAUDE.md      Kind: claude      Baseline: 2026-05-11

| #     | Check                 | Result | Notes                                      |
|-------|-----------------------|--------|--------------------------------------------|
| C1    | Role / Purpose        | PASS   | L3-5 "This file is the AI context document" |
| C2    | Operational Commands  | FAIL   | 명령 섹션 없음 — 유일한 코드블록(L35-45)은 트리 |
| C3    | Loading & Scope Model | WARN   | 독자는 명시, 로드 시점은 미기재               |
| C4    | Modular References    | PASS   | references/README.md 로 라우팅, 인라인 11줄   |
| C5    | Naming Conventions    | PASS   | L76-79 "Skill directory name is the identity" |
| C6    | Constraints / Rules   | PASS   | L74-93 Rules, L104 No emojis                |
| C7    | Size / Context Budget | PASS   | 106 lines — 400 한도 내                      |
| A-CL1 | Reference-by-path     | PASS   | 매니페스트 7개를 경로로 참조                  |
| A-CL2 | Permission Control    | WARN   | 2단계는 있으나 외부 부작용 규칙 없음           |
| A-CL3 | Thin Orchestrator     | N/A    | 오케스트레이터 문서가 아님                    |
| A-CL4 | Local + rules layout  | N/A    | .claude/ 트리와 CLAUDE.local.md 없음          |

Verdict: [FAIL] 6/9 passed (2 warnings)
  WARN(Step 2): CLAUDE.md / AGENTS.md / GEMINI.md 3개 발견 — 최우선 파일만 감사

Next: C2 를 먼저 고치고 harness:ai-context check 재실행
```

파일은 하나도 변경되지 않았다 — `check` 는 감사 전용이다.
