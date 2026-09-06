# dissect-builtin 사용 결과

> **한 줄 요약** — 내장 스킬 이름 하나를 받아 `docs/built-in-skills/<skill-name>/` 아래에 한국어 분석 `README.md` 와 원문 `PROMPT.md` 를 생성합니다.

> NOTE: **미실행 예시** — 이 스킬은 호출한 저장소의 `docs/built-in-skills/` 아래에 파일을 쓰므로 문서화 목적으로 실행하지 않았습니다. 명령·경로·산출물은 `skills/dissect-builtin/SKILL.md` 인용이며 실행 로그가 아닙니다.

```
내장 스킬 이름  ──▶  /harness:dissect-builtin  ──▶  README.md(한국어 분석) + PROMPT.md(원문)
```

## 1. 실행할 명령

```
/harness:dissect-builtin <skill-name>
/harness:dissect-builtin simplify   # 내장 스킬 simplify 해부
/harness:dissect-builtin loop       # 내장 스킬 loop 해부
/harness:dissect-builtin -h         # references/help.md 출력 후 중단
```

## 2. 입력

- **`<skill-name>`(필수)** — 해부할 Claude Code 내장 스킬 이름. Step 1 이
  `Skill(skill: "<skill-name>")` 로 로드하고, 주입된 원시 프롬프트 전문을 보존한다.
- **선행 조건(게이트):** 대상이 실제 내장 스킬이어야 한다. 로드에 실패하면 사용자에게 알리고 대안을 제시한 뒤 중단한다.
- **쓰기 대상:** 호출한 프로젝트 루트 기준 `docs/built-in-skills/<skill-name>/` — 작성자의 dotfiles 체크아웃을 전제하지 않는다.

## 3. 결과 (실행 시)

- **`docs/built-in-skills/<skill-name>/README.md`** — 에이전트 1개가 쓰는 한국어 분석.
  한줄 요약 / 동작 단계(Phase) / 단계별 상세 체크 항목 / 특징(병렬 실행, 쓰기 권한,
  도메인 특화 등)을 담고, 제목은 대상 스킬의 실제 단계에 맞춰 조정된다.
- **`docs/built-in-skills/<skill-name>/PROMPT.md`** — 부모가 컨텍스트의 원문을 직접
  옮겨 쓴다. 감싸는 제목도 코드 펜스도 없고, 요약·번역·재포맷하지 않는다. 정확한 사본
  이라 에이전트에 위임하지 않는다.
- **stdout 판정** — 성공 시 `[OK] harness:dissect-builtin` 아래 `Skill:`, 두 산출물
  경로를 담은 `Outputs:`, 그리고 `Next: /gh-pr:commit`. 실패 시
  `[FAIL] harness:dissect-builtin` 과 함께 `Step:`(Step 1 load / Step 2 agent /
  Step 2 write)과 `Detail:` 을 출력하고 즉시 중단한다.
- **남지 않는 것** — 출력 파일명으로 `SKILL.md` 는 쓰지 않는다(Claude Code 의 스킬
  로딩과 충돌). 커밋도 하지 않는다 — 그건 `/gh-pr:commit` 의 일이다.
