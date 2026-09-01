# harness-legacy-check 사용 결과

> **한 줄 요약** — 하네스 전체를 받아 읽기 전용 감사 리포트 파일 한 개를
> 생성합니다.

```
하네스 전체 (docs/skills/settings/hooks)  ──▶  /harness:harness-legacy-check
                                          ──▶  .claude/reports/harness-legacy-check.md
```

## 1. 실행한 명령

```
/harness:harness-legacy-check          # 범용 형식 — 전체 감사
/harness:harness-legacy-check --help   # 이번에 실행한 명령 (help 경로)
```

이번 세션에서는 사용자 결정에 따라 **help 경로만 실제로 실행**했다. 전체 감사
경로(`Workflow({ name: 'harness-legacy-check' })`)는 에이전트 9개를 띄우므로
실행하지 않았다. 아래 3절의 출력은 실제 관측한 것이고, 전체 감사 리포트는
이 문서에 포함되지 않는다.

## 2. 입력

`skills/harness-legacy-check/references/help.md`. Step 0 의 help 분기는 첫
인자가 `-h` / `--help` / `help` 일 때 이 파일을 그대로 출력하고 중단한다.

## 3. 결과

```
harness:harness-legacy-check — AI 하네스 읽기 전용 감사

역할: CLAUDE.md, AGENTS.md, skills, workflows, settings, hooks, MCP를
      5개 병렬 specialist agent로 감사
출력: .claude/reports/harness-legacy-check.md (덮어쓰기)
제한: 파일 수정/삭제 없음 — 분석 리포트 생성 전용
다음: /harness:harness-refactor 로 low-risk 개선 적용
```

의존하는 워크플로우가 실재하는지도 함께 확인했다 —
`~/.claude-work1/workflows/harness-legacy-check.js`, 448줄, `agent(` 호출 9회,
phase 5개(Inventory / Parallel Analysis / Refactor Planner / Adversarial
Review / Final Report). 파일은 하나도 변경되지 않았다.
