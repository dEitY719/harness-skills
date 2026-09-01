# plugin-guide — 설치된 플러그인 가이드 생성

**한 줄 요약** — 설치된 Claude Code 플러그인의 캐시된 `SKILL.md` 들을 읽어
`docs/guide/plugins/<PLUGIN>.md` 한국어 가이드 문서 하나를 산출하고,
`docs/guide/plugins/README.md` 인덱스에 한 줄을 추가한다.

## 언제 쓰고 언제 안 쓰는가

| 상황 | 사용 여부 |
|------|-----------|
| 설치한 플러그인이 어떤 스킬을 갖는지 한국어로 정리하고 싶다 | 사용 |
| 플러그인을 **설치**하고 싶다 | 사용 금지 — 직접 `/plugin install` |
| **내장** 스킬을 문서화하고 싶다 | 사용 금지 — `harness:dissect-builtin` |
| 문서를 커밋하고 싶다 | 사용 금지 — 이 스킬은 커밋하지 않는다 |

## 호출 형식

```
/harness:plugin-guide <plugin-name> [--force]
/harness:plugin-guide -h
```

| 인자 / 플래그 | 설명 | 기본값 | 필수 |
|---------------|------|--------|------|
| `<plugin-name>` | `<plugin>@<marketplace>` 또는 `<plugin>` 단독 | — | 예 |
| `--force` | 문서가 이미 있어도 통째로 재생성 | off | 아니오 |
| `-h`, `--help` | `references/help.md` 를 그대로 출력하고 중단 | — | — |

인자를 빠뜨리면 `Run /harness:plugin-guide -h for usage.` 만 출력하고 멈춘다.
출력 파일 이름은 언제나 `PLUGIN.md` 다.

## 동작 단계

1. **인자 파싱** — `@` 로 `PLUGIN` 과 `MARKETPLACE` 를 나눈다.
2. **설치 확인** — `claude/plugin/plugins.json` 의 `plugins` 배열에 대해
   `PLUGIN@` 를 **정확히 일치**로 매칭한다. 부분 문자열 `grep` 은 쓰지
   않는다 — `skills` 라는 플러그인이 `example-skills@...` 에 오탐되기 때문.
   0개 / 1개 / 2개 이상 각각의 처리는 `references/marketplace-resolution.md`.
3. **캐시 탐색 + 스킬 열거** —
   `find "$CFG/plugins/cache/<MARKETPLACE>/<PLUGIN>" -maxdepth 4 -iname SKILL.md`.
   버전 디렉터리가 여러 개면 `sort -V` 로 최고 버전만 남긴다. 0개면
   `스킬 없음, 문서화 대상 아님` 으로 중단한다. 10개를 넘으면 경고 한 줄만
   찍고 단일 파일로 계속 진행한다.
4. **멱등 스킵** — 대상 문서가 이미 있고 `--force` 가 없으면
   `이미 문서화됨 — 재생성하려면 --force` 를 출력하고 멈춘다. diff 나 병합은
   하지 않는다.
5. **문서 작성** — `references/doc-template.md` 의 3절 골격을 정확히 따른다:
   설치 방법 → 스킬 설명 → 사용법 예제.
6. **인덱스 갱신** — `docs/guide/plugins/README.md` 의 `## Index` 목록 **안**,
   마지막 `- [...]` 항목 뒤이자 다음 `## ` 헤더 앞에 한 줄을 삽입한다.
   파일 끝에 무작정 붙이지 않는다. 이미 링크가 있으면 건너뛴다(멱등).
7. **리포트** — `[OK]` 판정, 쓴/건너뛴 파일, 스킬 수, 다음 단계를 출력한다.

## 주의사항 / 제약

- **플러그인을 설치하지 않는다.** 미설치면 사용자에게 알리고 멈춘다.
- **커밋하지 않고 PR 도 열지 않는다.** 스킬 스모크 테스트도 범위 밖이다.
- 생성 문서는 한국어다. 원본 `SKILL.md` 는 영어이므로 복붙이 아니라 요약한다.
- 이모지는 어디에도 쓰지 않는다.
