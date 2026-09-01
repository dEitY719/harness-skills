# harness-refactor 사용 결과

> **한 줄 요약** — 감사 리포트를 받아 low-risk 개선 워크플로우 파일과 실제
> 하네스 변경을 생성합니다.

```
.claude/reports/harness-legacy-check.md  ──▶  /harness:harness-refactor
                                         ──▶  claude/workflows/harness-refactor.js + 파일 변경
```

## 1. 실행한 명령

```
/harness:harness-refactor        # 범용 형식 — 인자 없음
/harness:harness-refactor        # 이번에 실행한 명령
```

## 2. 입력

Step 1 은 감사 리포트를 세 순서로 찾는다. 이번 실행에서 실제로 관측한 상태:

| 순서 | 찾는 대상 | 결과 |
|------|-----------|------|
| 1 | `.claude/reports/harness-legacy-check.md` | 없음 (`No such file or directory`) |
| 2 | 현재 세션의 harness-legacy-check 출력 | 없음 (help 경로만 실행됨) |
| 3 | 둘 다 없음 | 가드 발동 → 중단 |

## 3. 결과

입력이 없으므로 스킬은 Step 2 이후로 진행하지 않고 Step 1 에서 멈췄다.
`claude/workflows/harness-refactor.js` 는 생성되지 않았고, 하네스 파일도
변경되지 않았다.

```
harness-legacy-check 결과가 없습니다. 먼저 /harness-legacy-check 를 실행해 주세요.
```

이것은 오류가 아니라 설계된 가드 경로다 — 감사 없이 하네스를 고치는 일을
막는다. 정상 경로를 보려면 `/harness:harness-legacy-check` 로 리포트를 만든
뒤 다시 실행하면 된다.
