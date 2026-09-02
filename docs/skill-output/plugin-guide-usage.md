# plugin-guide 사용 결과

> **한 줄 요약** — 설치된 플러그인 이름 하나를 받아 캐시된 `SKILL.md` 들을 읽고 한국어 가이드 문서 1개를 쓴 뒤 plugins 인덱스를 갱신합니다.

> NOTE: **미실행 예시** — 이 스킬은 사용자 dotfiles 저장소에 가이드 문서를 쓰고 plugins 인덱스를 갱신하므로 문서화 목적으로 실행하지 않았습니다. 명령·경로·출력 형식은 `skills/plugin-guide/SKILL.md` 인용이며 실행 로그가 아닙니다.

```
설치된 플러그인 이름  ──▶  /harness:plugin-guide  ──▶  한국어 가이드 문서 1개 + 인덱스 한 줄
```

## 1. 실행할 명령

```
/harness:plugin-guide <plugin>[@<marketplace>] [--force]
/harness:plugin-guide ponytail@ponytail      # marketplace 명시
/harness:plugin-guide andrej-karpathy-skills # plugins.json 에서 marketplace 추론
/harness:plugin-guide -h                     # references/help.md 출력 후 중단
```

## 2. 입력

- **플러그인 이름(필수)** — `<plugin>@<marketplace>` 또는 `<plugin>` 단독. `@` 로 쪼개며
  출력 파일명은 언제나 `PLUGIN.md` 다. 인자가 없으면 usage 한 줄만 출력하고 중단.
- **`claude/plugin/plugins.json`** — 설치 여부의 SSOT. `plugins` 배열의 `@` 앞 세그먼트를 정확히
  비교한다(substring grep 금지). 미설치면 설치 안내만 출력하고 중단하고, 같은 이름이 여러
  marketplace 에 있으면 추측 없이 후보 목록을 내고 중단한다.
- **캐시된 `SKILL.md` 들** — `$CLAUDE_CONFIG_DIR/plugins/cache/<marketplace>/<plugin>/` 아래를 `find -maxdepth 4 -iname SKILL.md`, 버전 디렉터리가 여럿이면 최고 버전만.
- **게이트:** `SKILL.md` 0개면 `스킬 없음, 문서화 대상 아님` 으로 중단. 대상 문서가 이미 있고 `--force` 가 없으면 `이미 문서화됨 — 재생성하려면 --force` 로 중단.

## 3. 결과 (실행 시)

- **가이드 문서 1개** — `docs/guide/plugins/<PLUGIN>.md`. `references/doc-template.md` 가 규정한
  한국어 3섹션 골격(설치 방법 → 스킬 설명 → 사용법 예제)이고, 스킬 설명은 스킬 1개당 한 행
  (스킬 / 성격 / 하는 일)의 표다. `--force` 는 병합이 아니라 파일 전체를 덮어쓴다.
- **인덱스 한 줄** — `docs/guide/plugins/README.md` 의 `## Index` 목록 안, 마지막 `- [...]` 뒤이자 다음
  `## ` 헤더 앞에 `- [<PLUGIN>](./<PLUGIN>.md) — <한 줄 요약>` 삽입. 같은 링크가 이미 있으면 스킵.
- **stdout 보고** — `references/help.md` 의 "출력 형식"대로 `[OK] docs/guide/plugins/<plugin>.md 생성
  (스킬 N개)`, 인덱스 갱신 줄, 문서 검토 후 수동 커밋하라는 Next 줄. 스킵 시에는 `[SKIP] ... 이미 존재`.
- **남지 않는 것** — 플러그인 설치도, 커밋도, PR 도 없다. 스킬을 실행해 보지도 않는다.
