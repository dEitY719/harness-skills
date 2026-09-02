# ai-context 사용 결과

> **한 줄 요약** — 컨텍스트 파일 1개(`AGENTS.md`)를 받아 코어+어댑터 검사 판정표와 `[OK]`/`[FAIL]` 리포트 1건을 생성합니다.

```
AGENTS.md  ──▶  /harness:ai-context check  ──▶  판정표 + Verdict + Next 리포트 1건
```

## 1. 실행한 명령

`/harness:ai-context check AGENTS.md` — SKILL.md 의 Step 1~4 를 이 저장소에서 그대로 수행했다. `check` 는 read-only 라 대상 파일은 변경되지 않았다.

## 2. 입력

- **대상** — 저장소 루트 `AGENTS.md`(=`CLAUDE.md` 심볼릭 링크, 143줄 / 6,684 bytes). 경로를 명시했으므로 자동 탐지(`CLAUDE.md` 우선)를 거치지 않았고, 파일명에서 어댑터 `agents` 가 결정되어 코어 C1~C7 + A-AG1~A-AG4 를 `references/industry-baseline.md` 스냅샷 2026-05-11 기준으로 돌렸다.

## 3. 결과

```
## harness:ai-context — check
File: AGENTS.md (symlink -> CLAUDE.md) | Kind: agents | Baseline: 2026-05-11
| #     | Check                 | Result | Notes                                          |
|-------|-----------------------|--------|------------------------------------------------|
| C1    | Role / Purpose        | PASS   | L1-4 역할 선언 + L15-35 "What this repo is"    |
| C2    | Operational Commands  | PASS   | L37-64 "Verifying a change locally" — 실행 가능한 명령 4개(L42-57) + CI 게이트 2개(L61-64) |
| C3    | Loading & Scope Model | PASS   | L6-13 로드 시점(세션 시작 project memory)과 독자(Codex 심볼릭 링크, Gemini 예외) 명시 |
| C4    | Modular References    | PASS   | 최대 인라인 블록 14줄(L42-57), L95 가 references/README.md 로 위임 |
| C5    | Naming Conventions    | PASS   | L113-118 디렉터리명=identity, bare vs 네임스페이스 |
| C6    | Constraints / Rules   | PASS   | L101-109 API 규칙 + L111-130 변경 규칙 + L141-143 No emojis |
| C7    | Size / Context Budget | PASS   | 143 lines — 400 이하                           |
| A-AG1 | Discovery             | PASS   | 저장소 루트에 위치 — Codex 자동 탐색 경로      |
| A-AG2 | Override / fallback   | N/A    | 중첩 AGENTS.md 없음 (L12-13 이 명시)           |
| A-AG3 | Payload budget        | PASS   | 6,684 bytes 단일 파일                          |
| A-AG4 | Context Map           | N/A    | 중첩 없음 — Context Map 불필요                 |
Verdict: [OK] 9/9 passed (0 warnings)
Issues & Improvements
  - (없음)

Next: 구조 변경이 생기면 harness:ai-context check 재실행
```
