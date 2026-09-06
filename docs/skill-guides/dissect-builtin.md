# dissect-builtin

> 한 줄 요약 — Claude Code **내장 스킬 1개**의 프롬프트를 Skill 도구로 불러와 해부하고, `docs/built-in-skills/<skill-name>/` 아래에 한국어 분석 문서 `README.md` 와 원문 그대로의 `PROMPT.md` **2개 파일**을 남긴다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때** — 내장 스킬(`simplify`, `loop`, `code-review` 등)이 실제로 무엇을 시키는지
알아야 할 때. 프롬프트 원문을 손으로 옮겨 적는 대신, 원문 사본(`PROMPT.md`)과 한국어
구조 분석(`README.md`)을 한 번에 만들어 둔다. 내장 스킬은 하네스 업데이트마다 조용히
바뀌므로, 이 스킬의 산출물은 "그 시점의 프롬프트"를 고정한 스냅샷 역할도 한다.

**안 쓸 때 — 형제 스킬로 가는 경계:**

- 대상이 내장 스킬이 아니라 **설치된 플러그인**이면 `/harness:plugin-guide` 다.
  그쪽은 캐시된 `SKILL.md` 들을 파싱해 `docs/guide/plugins/<PLUGIN>.md` 를 쓰고
  플러그인 인덱스까지 갱신한다. 이 스킬은 스킬 **1개**의 프롬프트만 다루고
  인덱스를 건드리지 않는다.
- **내가 만든 스킬**의 품질을 점검하는 것은 `authoring:skill-check`, 길이를 줄이는 것은
  `authoring:skill-refactor` 다. 이 스킬은 남의 스킬을 읽어 기록할 뿐, 대상 스킬을 고치지 않는다.
- 하네스 전체(`CLAUDE.md`, settings, hooks, MCP)를 감사하는 것은
  `/harness:harness-legacy-check`, 그 리포트를 적용하는 것은 `/harness:harness-refactor` 다.
- 산출물을 커밋하는 것은 이 스킬의 일이 아니다. `[OK]` 판정의 `Next:` 가
  `/gh-pr:commit` 를 가리킨다.

**대상이 내장 스킬이 아니면** Step 1 의 Skill 로드가 실패한다. 그때는 억지로
진행하지 않고 사용자에게 알린 뒤 대안을 제시하고 멈춘다.

## 호출 형식

```
/harness:dissect-builtin <skill-name>
/harness:dissect-builtin -h | --help | help
```

`skills/dissect-builtin/references/help.md` 가 1차 근거다.

| 인자 | 기본값 | 설명 |
|------|--------|------|
| `<skill-name>` | — (필수) | 해부할 내장 스킬 이름. 예: `simplify`, `loop` |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 중단. 다른 동작 없음 |

예시:

- `/harness:dissect-builtin simplify`
- `/harness:dissect-builtin loop`
- `/harness:dissect-builtin -h`

## 동작 단계

순서대로 실행하며, 어느 단계에서든 오류(스킬 로드 실패, 에이전트 실패, 쓰기 실패)가
나면 **즉시 멈추고 `[FAIL]` 판정을 낸다.** 부분 산출물을 남긴 채 다음 단계로 넘어가지 않는다.

1. **Step 1 — 스킬 프롬프트 로드.** `Skill(skill: "<skill-name>")` 으로 대상 내장
   스킬을 불러온다. 원시 프롬프트가 컨텍스트에 주입되며, 그것이 `PROMPT.md` 의 원본이다.
   여기서 로드가 실패하면 그 스킬은 내장이 아니라는 뜻이므로 Step 2 로 가지 않는다.
2. **Step 2 — 산출물 2개 쓰기.** 출력 디렉터리는 호출한 프로젝트 루트 기준
   `docs/built-in-skills/<skill-name>/` 이다.

   | 산출물 | 경로 | 형식 |
   |--------|------|------|
   | `README.md` | `docs/built-in-skills/<skill-name>/README.md` | 한국어 Markdown |
   | `PROMPT.md` | `docs/built-in-skills/<skill-name>/PROMPT.md` | 원문 그대로(verbatim) |

   - **`PROMPT.md` — 부모가 직접 쓴다.** 컨텍스트에 이미 들어온 원문을 그대로 옮긴다.
     감싸는 제목도, 코드 펜스도 붙이지 않는다. 정확한 사본을 만드는 일에 에이전트를
     한 번 더 태우면 나아질 여지는 없고 망가질 여지만 생기므로 위임하지 않는다.
   - **`README.md` — 에이전트 1개.** 로드한 프롬프트를 분석해 한국어로 쓴다. 필수 항목은
     ① 한줄 요약 ② 동작 단계(Phase) ③ 각 단계의 상세 체크 항목(있는 경우)
     ④ 특징(병렬 실행, 쓰기 권한, 도메인 특화 등 주목할 설계 특성). 브리프 전문은
     `skills/dissect-builtin/references/readme-template.md` 에 있다. 권장 골격이
     있지만 **고정 템플릿을 강요하지 말고 대상 스킬의 실제 단계에 맞춰 제목을 조정**한다.
3. **Step 3 — 확인 및 판정.** 에이전트가 끝나기를 기다린 뒤 결정적 판정을 낸다.

   ```
   [OK] harness:dissect-builtin
     Skill:    <skill-name>
     Outputs:  docs/built-in-skills/<skill-name>/README.md
               docs/built-in-skills/<skill-name>/PROMPT.md
     Next:     /gh-pr:commit
   ```

   실패 시:

   ```
   [FAIL] harness:dissect-builtin
     Step:    <Step 1 load | Step 2 agent | Step 2 write>
     Detail:  <error or skill not built-in>
   ```

## 주의사항과 제약

**출력 파일명으로 `SKILL.md` 를 쓰지 않는다.** 이것이 이 스킬에서 가장 중요한 제약이다.
Claude Code 는 스킬 트리에서 `SKILL.md` 를 발견하면 그것을 **로드 가능한 스킬 정의로
취급**한다. 해부 산출물을 `SKILL.md` 로 저장하면 "분석 문서"가 아니라 "설치된 또 하나의
스킬"이 되어 스킬 로딩 메커니즘과 충돌한다. 그래서 분석본은 `README.md`, 원문은
`PROMPT.md` 다. 산출물 파일명으로 `SKILL.md` 가 요청되면 거부한다.

**`PROMPT.md` 는 원본의 정확한 사본이어야 한다.** 요약하지도, 번역하지도, 재포맷하지도
않는다. 이 파일의 가치는 전적으로 "손대지 않았다"는 데 있다 — 나중에 내장 스킬이
바뀌었는지 비교하려면 원문이어야 한다. 한국어로 쓰는 것은 `README.md` 쪽이고,
거기서도 기술 용어는 영어를 그대로 쓴다.

**쓰기 위치는 호출한 저장소다.** 출력 경로 `docs/built-in-skills/<skill-name>/` 는
**호출한 프로젝트 루트 기준**이다. 작성자의 dotfiles 체크아웃을 전제하지 않으므로,
이 플러그인을 설치한 어느 저장소에서 호출하든 산출물은 그 저장소 안에 생긴다.
대상 디렉터리에 쓸 수 없으면 Step 2 의 쓰기가 실패하고
`[FAIL] ... Step: Step 2 write` 로 중단된다.

**오류는 조용히 넘기지 않는다.** 이 스킬에는 soft-fail 단계가 없다. 세 단계 어디서든
실패하면 그 자리에서 멈추고 `[FAIL]` 과 함께 실패한 Step 을 밝힌다. 반쪽짜리 산출물
(README 만 있고 PROMPT 는 없는 디렉터리)을 남기지 않기 위한 설계다.

**커밋하지 않는다.** 파일을 쓸 뿐, `git add` 도 커밋도 하지 않는다. `[OK]` 판정의
`Next:` 가 `/gh-pr:commit` 를 안내하는 이유다.
