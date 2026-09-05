# harness-legacy-check

> 한 줄 요약 — AI 코딩 하네스 전체(CLAUDE.md, AGENTS.md, skills, workflows, settings, hooks, MCP)를 **읽기 전용으로 감사**해 `.claude/reports/harness-legacy-check.md` 에 **감사 리포트 1개**를 저장한다. 어떤 파일도 고치거나 지우지 않는다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때** — 하네스가 오래돼 무엇이 남아 있는지부터 알고 싶을 때. 예전 CLAUDE.md 규칙이
아직 유효한지, 안 쓰는 skill 이나 workflow 가 쌓였는지, settings/hooks/MCP 설정이 실제
동작과 어긋나는지를 한 번에 훑는다. 정리 작업의 **첫 단계**이며, 그 자체로는 아무것도
바꾸지 않으므로 부담 없이 돌려 현황만 확보하는 용도로 쓸 수 있다.

**안 쓸 때 — 형제 스킬로 가는 경계:**

- 리포트를 읽고 **실제로 고쳐야 할 때는 `/harness:harness-refactor`**. 이 스킬은 절대
  쓰지 않는다. refactor 쪽이 리포트에서 low-risk 항목만 골라 워크플로우를 만들고 적용한다.
- 감사 범위를 **AI 컨텍스트 문서 하나(CLAUDE.md / AGENTS.md / GEMINI.md)로 좁히고**
  싶다면 `/harness:ai-context check` 가 더 정밀하다. 이 스킬은 하네스 전체를 넓게 본다.
- 개별 `SKILL.md` 의 구조 점검은 `authoring:skill-check`, 셸 스크립트는 `authoring:sh-check` 다. 이 스킬은
  스킬 하나를 파고들지 않고 하네스라는 집합을 본다.

`legacy-check` / `refactor` 의 분리는 의도된 것이다. 사람이 리포트를 먼저 읽고
무엇을 적용할지 판단한 뒤에야 하네스에 쓰기가 일어나도록 하기 위한 분리선이다.

## 호출 형식

```
/harness:harness-legacy-check
/harness:harness-legacy-check -h | --help | help
```

| 인자 | 기본값 | 설명 |
|------|--------|------|
| (없음) | — | 위치 인자를 받지 않는다. 감사 범위와 출력 경로는 워크플로우가 고정한다 |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 중단. 워크플로우 실행 없음 |

## 동작 단계

1. **Step 1 — 워크플로우 실행.** 스킬 본체가 하는 일은 사실상 이 호출 1건이다.

   ```
   Workflow({ name: 'harness-legacy-check' })
   ```

   실제 감사는 이 워크플로우 **내부의 병렬 specialist agent 5개**가 수행한다. 감사 로직이
   스킬이 아니라 워크플로우 쪽에 있기 때문에, SKILL.md 는 100줄 규칙 안에서 얇게 유지되고
   모델 티어도 haiku 로 충분하다는 메타데이터가 붙어 있다. 워크플로우가 끝나면
   `.claude/reports/harness-legacy-check.md` 에 리포트가 저장된다(같은 경로 **덮어쓰기**).
   실패하면 즉시 `[FAIL] harness:harness-legacy-check — <이유>` 를 출력하고 중단한다.
2. **Step 2 — 완료 보고.** 리포트 경로와 다음 단계를 함께 출력한다.

   ```
   [OK] harness:harness-legacy-check — 완료
     리포트: .claude/reports/harness-legacy-check.md
     다음: /harness:harness-refactor 로 low-risk 개선 적용
   ```

## 주의사항과 제약

**읽기 전용 계약** — 이 스킬은 파일을 수정하지도 삭제하지도 않는다. 유일한 쓰기는
`.claude/reports/harness-legacy-check.md` 한 개를 만드는 것뿐이고, 그마저도 분석 결과를
담는 리포트다. 저장소 CLAUDE.md 가 이 계약을 명시적으로 보호하므로(`harness-legacy-check`
와 `ai-context check` 는 read-only), 여기에 "찾은 김에 고치기" 를 추가하면 안 된다.

**리포트는 덮어쓰기다** — 실행할 때마다 같은 경로를 갈아쓴다. 이전 감사 결과를 비교용으로
남기고 싶다면 실행 전에 따로 복사해 두거나, 리포트를 커밋해 git 히스토리에 남긴다.

**Workflow 도구 의존** — 내부적으로 Claude Code 의 `Workflow` 도구를 쓴다. 실행되지 않거나
오류가 나면 `/config` 에서 `Dynamic workflows` 와 `Ultracode keyword trigger` 가 둘 다
`true` 인지 확인한다. 두 항목은 `/config` 에서 직접 바꿀 수 있다. 다른 하네스에서는
이 도구가 없어 advisory-only 로 취급된다.

**짝 스킬로 이어지는 계약** — 저장된 리포트가 그대로 `harness:harness-refactor` 의 입력이
된다. 순서는 아래와 같고, refactor 는 리포트를 못 찾으면 "먼저 /harness-legacy-check 를
실행해 주세요" 로 중단한다.

1. `/harness:harness-legacy-check` — 감사 실행 + 리포트 저장
2. `/harness:harness-refactor` — 리포트를 읽고 low-risk 항목만 적용

따라서 리포트 경로와 형식은 두 스킬 사이의 인터페이스다. 경로를 바꾸려면 양쪽을 함께
고쳐야 한다.
