# harness-legacy-check 사용 결과

> **한 줄 요약** — 하네스 전체를 읽기 전용으로 감사해 `.claude/reports/harness-legacy-check.md` 에 리포트 1개를 저장합니다.

> NOTE: **미실행 예시** — 이 스킬은 다중 에이전트 워크플로를 실행하고 리포트를 사용자 하네스의 `.claude/reports/` 에 쓰므로 문서화 목적으로 실행하지 않았습니다. 명령·경로·출력 형식은 `skills/harness-legacy-check/SKILL.md` 인용이며 실행 로그가 아닙니다.

```
하네스 전체(문서·skills·workflows·settings·hooks·MCP)  ──▶  /harness:harness-legacy-check  ──▶  감사 리포트 1개
```

## 1. 실행할 명령

```
/harness:harness-legacy-check          # 감사 실행 + 리포트 저장
/harness:harness-legacy-check -h       # references/help.md 출력 후 중단
```

## 2. 입력

- **하네스 자체** — CLAUDE.md, AGENTS.md, skills, workflows, settings, hooks, MCP.
  위치 인자를 받지 않으므로 감사 범위는 사용자가 지정하지 않는다.
- **선행 조건(게이트):** Claude Code 의 `Workflow` 도구가 동작해야 한다. `/config` 에서
  `Dynamic workflows` 와 `Ultracode keyword trigger` 가 둘 다 `true` 여야 한다.
- **덮어쓰기 대상:** 이전 실행의 리포트가 있다면 이번 실행이 같은 경로를 갈아쓴다.

## 3. 결과 (실행 시)

- **감사 리포트 1개** — `.claude/reports/harness-legacy-check.md`. 워크플로우 내부의
  병렬 specialist agent 5개가 만든 분석 결과이며, 실행할 때마다 같은 경로를 덮어쓴다.
- **stdout 완료 보고** — 리포트 경로와 다음 단계가 함께 나온다.

  ```
  [OK] harness:harness-legacy-check — 완료
    리포트: .claude/reports/harness-legacy-check.md
    다음: /harness:harness-refactor 로 low-risk 개선 적용
  ```

- **실패 시** — `[FAIL] harness:harness-legacy-check — <이유>` 를 출력하고 즉시 중단한다.
- **바뀌지 않는 것** — 하네스의 어떤 파일도 수정·삭제되지 않는다. 개선 적용은
  리포트를 입력으로 받는 `/harness:harness-refactor` 의 일이다.
