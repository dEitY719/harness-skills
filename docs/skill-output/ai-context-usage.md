# ai-context 사용 결과

> **한 줄 요약** — 컨텍스트 파일 1개(`AGENTS.md`)를 받아 코어+어댑터 검사 판정표와 `[OK]`/`[FAIL]` 리포트 1건을 생성합니다.

```
AGENTS.md  ──▶  /harness:ai-context check  ──▶  판정표 + Verdict + Next 리포트 1건
```

## 1. 실행한 명령

`/harness:ai-context check AGENTS.md` — SKILL.md 의 Step 1~4 를 이 저장소에서 그대로 수행했다. `check` 는 read-only 라 대상 파일은 변경되지 않았다.

## 2. 입력

- **대상** — 저장소 루트 `AGENTS.md`(=`CLAUDE.md` 심볼릭 링크, 106줄 / 5,297 bytes). 경로를 명시했으므로 자동 탐지(`CLAUDE.md` 우선)를 거치지 않았고, 파일명에서 어댑터 `agents` 가 결정되어 코어 C1~C7 + A-AG1~A-AG4 를 `references/industry-baseline.md` 스냅샷 2026-05-11 기준으로 돌렸다.

## 3. 결과

```
## harness:ai-context — check
File: AGENTS.md (symlink -> CLAUDE.md) | Kind: agents | Baseline: 2026-05-11
| #     | Check                 | Result | Notes                                          |
|-------|-----------------------|--------|------------------------------------------------|
| C1    | Role / Purpose        | PASS   | L1-5 역할 선언 + L7-27 "What this repo is"     |
| C2    | Operational Commands  | FAIL   | 실행 가능한 명령 0개 (유일한 코드펜스 L35-45는 레이아웃 목록) |
| C3    | Loading & Scope Model | WARN   | L3-5 는 누가 읽는지만 명시, 로드 시점은 미기재 |
| C4    | Modular References    | PASS   | 최대 인라인 블록 11줄, L58 이 references/ 로 위임 |
| C5    | Naming Conventions    | PASS   | L76-81 디렉터리명=identity, bare vs 네임스페이스 |
| C6    | Constraints / Rules   | PASS   | L74-93 Do/Don't 목록 + L104-106 No emojis      |
| C7    | Size / Context Budget | PASS   | 106 lines — 400 이하                           |
| A-AG1 | Discovery             | PASS   | 저장소 루트에 위치 — Codex 자동 탐색 경로      |
| A-AG2 | Override / fallback   | N/A    | 중첩 AGENTS.md 없음 (루트 1개)                 |
| A-AG3 | Payload budget        | PASS   | 5,297 bytes 단일 파일                          |
| A-AG4 | Context Map           | N/A    | 중첩 없음 — Context Map 불필요                 |
Verdict: [FAIL] 7/9 passed (1 warning)
Issues & Improvements
  - FAIL: C2 — setup / lint / test / build 어느 것도 없음 → 실행 가능한 명령 섹션 추가
  - WARN: C3 — "AGENTS.md is a symlink to it, so ... read the same text" → 로드 시점 명시
Next: 최우선 FAIL(C2)을 고친 뒤 harness:ai-context check 재실행
```
