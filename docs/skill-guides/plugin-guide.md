# plugin-guide

> 한 줄 요약 — 이미 설치된 Claude Code 플러그인 1개의 캐시된 `SKILL.md` frontmatter 를 읽어 **한국어 가이드 문서 1개**(`docs/guide/plugins/<PLUGIN>.md`)를 쓰고, `docs/guide/plugins/README.md` 의 plugins 인덱스에 한 줄을 넣는다. 플러그인을 설치하지도, 커밋하지도 않는다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때** — `/plugin install` 로 플러그인을 이미 설치했고, 그 안에 어떤 스킬이
들어 있는지 팀이 읽을 한국어 문서로 남기고 싶을 때. 근거는 사람의 기억이 아니라
`$CLAUDE_CONFIG_DIR/plugins/cache/` 아래에 실제로 캐시된 `SKILL.md` 파일들이라,
설치돼 있지 않은 플러그인은 문서화 대상이 아니다.

**안 쓸 때 — 경계:**

- **아직 설치하지 않았다면 먼저 `/plugin install`.** 이 스킬은 설치를 대신하지
  않는다. 미설치를 확인하면 설치 안내 블록만 출력하고 멈춘다.
- **문서를 커밋까지 하고 싶다면 별도로 커밋한다.** 이 스킬은 파일을 쓴 뒤 멈추며
  커밋도 PR 도 만들지 않는다(Non-Goal).
- **플러그인이 아니라 Claude Code 내장 스킬을 문서화하려면 `/harness:dissect-builtin`.**
  이쪽은 marketplace 로 설치된 플러그인만 다룬다.
- **스킬이 실제로 동작하는지 확인하려는 것이라면 대상이 아니다.** smoke test 는
  범위 밖이고, 이 스킬은 frontmatter 를 읽을 뿐 스킬을 실행하지 않는다.

## 호출 형식

```
/harness:plugin-guide <plugin>[@<marketplace>] [--force]
/harness:plugin-guide -h | --help | help
```

`references/help.md` 가 1차 근거다. 위치 인자 #1 은 플러그인 이름, #2 는 `--force`.
플러그인 이름은 `@` 를 기준으로 `PLUGIN` 과 (선택) `MARKETPLACE` 로 쪼개지며,
**출력 파일명은 언제나 `PLUGIN.md`** 다 — marketplace 이름은 파일명에 들어가지 않는다.

| 인자 | 기본값 | 설명 |
|------|--------|------|
| `<plugin>[@<marketplace>]` | — (필수) | 문서화할 플러그인. marketplace 를 생략하면 `plugins.json` 에서 추론한다 |
| `--force` | off | 대상 문서가 이미 있어도 재생성. **파일 전체를 덮어쓴다** |
| `-h` / `--help` / `help` | — | `references/help.md` 를 그대로 출력하고 중단. 파일 읽기/쓰기 없음 |

예시:

- `/harness:plugin-guide ponytail@ponytail` — marketplace 명시
- `/harness:plugin-guide andrej-karpathy-skills` — marketplace 는 `plugins.json` 에서 추론
- `/harness:plugin-guide ponytail --force` — 기존 문서를 덮어쓰고 재생성

인자를 아예 주지 않으면 `Run /harness:plugin-guide -h for usage.` 만 출력하고 멈춘다.

## 동작 단계

1. **Step 1 — 인자 파싱.** `<plugin-name>` 을 `@` 로 분리하고, 저장소 루트 `ROOT` 와
   설정 디렉터리 `CFG=${CLAUDE_CONFIG_DIR:-$HOME/.claude}` 를 잡는다.
2. **Step 2 — 설치 확인.** `claude/plugin/plugins.json` 의 `plugins` 배열(원소는
   `"<plugin>@<marketplace>"` 문자열)에 대해 **`@` 앞 세그먼트만 정확히 비교**한다.
   자세한 분기는 `references/marketplace-resolution.md`.
3. **Step 3 — 캐시 탐색과 스킬 열거.**
   `find "$CFG/plugins/cache/<MARKETPLACE>/<PLUGIN>" -maxdepth 4 -iname SKILL.md`.
   버전 디렉터리가 여러 개면 `sort -V` 로 **가장 높은 버전만** 남긴다. 각
   `SKILL.md` 에서 frontmatter 의 `name` / `description` 을 읽고 본문을 훑어 핵심
   규칙 1개를 뽑아 "하는 일" 1-2줄 요약을 만든다.
4. **Step 4 — 멱등 스킵.** `docs/guide/plugins/<PLUGIN>.md` 가 이미 있고 `--force`
   가 없으면 `이미 문서화됨 — 재생성하려면 --force` 를 출력하고 멈춘다. 기존
   문서를 diff 하거나 섹션 단위로 병합하지 않는다.
5. **Step 5 — 문서 작성.** `references/doc-template.md` 의 3섹션 골격
   (설치 방법 → 스킬 설명 → 사용법 예제)을 그대로 따라 한국어로 쓴다. 원본
   `SKILL.md` 는 영어이므로 **요약하되 원문을 복붙하지 않는다**.
6. **Step 6 — 인덱스 갱신.** `docs/guide/plugins/README.md` 의 `## Index` 목록
   안, 마지막 `- [...]` 항목 뒤이자 다음 `## ` 헤더 앞에
   `- [<PLUGIN>](./<PLUGIN>.md) — <한 줄 한국어 요약>` 을 삽입한다. 파일 끝에
   무작정 append 하지 않는다. 이미 `./<PLUGIN>.md` 를 링크하는 줄이 있으면 스킵(멱등).
7. **Step 7 — 보고.** `references/help.md` 의 "출력 형식" 대로 `[OK]` 판정, 쓴/스킵한
   파일, 스킬 개수, 그리고 다음 단계(문서 검토 후 수동 커밋)를 출력한다.

## 주의사항과 제약

**substring grep 금지 (Step 2 의 핵심 규칙)** — marketplace 해석은 반드시
`claude/plugin/plugins.json` 의 `plugins` 배열을 기준으로 하고, `grep "PLUGIN@"`
같은 부분 문자열 검색을 쓰지 않는다. `skills` 라는 이름의 플러그인을 찾을 때
`example-skills@anthropic-agent-skills` 가 함께 걸려 엉뚱한 플러그인을 문서화하게
되기 때문이다. `jq` 로 `split("@")[0] == $p` 를 비교한다. 분기는 셋이다:

- **정확히 1건** → 그 항목의 `@` 뒤를 `MARKETPLACE` 로 삼고 진행.
- **0건** → 미설치. `MARKETPLACE` 를 알면 `marketplaces.json` 에서 `owner/repo` 를
  찾아 설치 안내를 출력하고 멈춘다. 모르면 안내를 **지어내지 않고**
  `<plugin>@<marketplace>` 형태로 재실행하라고만 알린다.
- **2건 이상** → 같은 이름이 여러 marketplace 에 설치된 경우(현재 `superpowers` 가
  그렇다). **어느 쪽인지 추측하지 않고 멈춘다.** 후보 목록을 출력하고 명시적인
  `<plugin>@<marketplace>` 로 재실행하게 한다.

**no-skills 에러 케이스** — 캐시 디렉터리에서 `SKILL.md` 를 **0개** 발견하면
`스킬 없음, 문서화 대상 아님` 을 보고하고 멈춘다. 빈 문서를 만들지 않는다.

**스킬이 11개 이상이어도 파일은 하나** — `스킬 N개 (>10) — YAGNI: 단일 파일로 생성`
경고 한 줄만 출력하고 그대로 단일 파일로 계속한다. 하위 디렉터리로 쪼개는 로직을
만들지 않는다.

**`--force` 는 병합이 아니라 전체 덮어쓰기** — 기존 문서에 손으로 덧붙인 내용이
있다면 사라진다. 스킵과 덮어쓰기 둘뿐이고 그 사이의 절충은 없다.

**절대 하지 않는 것 (경계 계약)**

- 플러그인을 **설치하지 않는다.** `/plugin install` 도, marketplace 추가도 하지
  않는다. 미설치는 사용자에게 안내하고 멈추는 것으로 끝난다.
- **커밋하지 않고 PR 도 열지 않는다.** 문서를 쓴 뒤 멈춘다. 커밋은 사람이 문서를
  검토한 뒤 직접 한다.
- 스킬을 **smoke test 하지 않는다.** frontmatter 를 읽을 뿐 실행하지 않는다.
- `docs/guide/README.md` 에 이미 있는 `plugins/` 링크는 건드리지 않는다(정말로
  없을 때만 추가).

**언어 규칙** — 생성되는 문서는 한국어(`docs/AGENTS.md` Language Policy)이고 원본
`SKILL.md` 는 영어로 남는다. 둘을 섞지 않는다. 어디에도 이모지를 쓰지 않는다.
