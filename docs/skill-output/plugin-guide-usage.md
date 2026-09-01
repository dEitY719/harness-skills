# plugin-guide 사용 결과

> **한 줄 요약** — 설치된 플러그인의 캐시된 SKILL.md 들을 받아 한국어 가이드
> 문서 한 개와 인덱스 한 줄을 생성합니다.

```
캐시된 SKILL.md × N  ──▶  /harness:plugin-guide  ──▶  <PLUGIN>.md + 인덱스 갱신
```

## 1. 실행한 명령

```
/harness:plugin-guide <plugin>[@<marketplace>] [--force]   # 범용 형식
/harness:plugin-guide packaging@packaging-skills           # 이번에 실행한 명령
```

## 2. 입력

Step 2 에서 `installed_plugins.json` 을 정확 일치로 매칭해
`packaging@packaging-skills` 1건을 확인했다. Step 3 의
`find ... -maxdepth 4 -iname SKILL.md` 가 버전 디렉터리 `0.1.0` 아래에서
**SKILL.md 4개**를 찾았다.

```
skills/create/SKILL.md              skills/structure-check/SKILL.md
skills/rename-repo/SKILL.md         skills/structure-refactor/SKILL.md
```

마켓플레이스 소스는 `dEitY719/packaging-skills` (github).

## 3. 결과

Step 4 멱등 스킵 검사에서 대상 파일이 없어 생성으로 진행했다. 출력 루트는
dotfiles 저장소 대신 이번 실행용 샌드박스를 썼다.

| 산출물 | 경로 | 결과 |
|--------|------|------|
| 가이드 | `/tmp/claude-1000/-home-bwyoon-para-project-skills-harness-skills-feat-1/2b41ddbe-5bd8-4644-9057-9695525651e0/scratchpad/plugin-guide-run/docs/guide/plugins/packaging.md` | 51줄 / 2,708 bytes |
| 인덱스 | `/tmp/claude-1000/-home-bwyoon-para-project-skills-harness-skills-feat-1/2b41ddbe-5bd8-4644-9057-9695525651e0/scratchpad/plugin-guide-run/docs/guide/plugins/README.md` | `## Index` 안에 1줄 삽입 |

생성된 문서는 템플릿대로 3절(설치 방법 / 스킬 설명 / 사용법 예제)이며,
스킬 설명 표는 4행(`create`, `structure-check`, `structure-refactor`,
`rename-repo`)이다.

```
[OK] harness:plugin-guide — packaging@packaging-skills
  스킬 4개  |  생성: packaging.md  |  인덱스: 1줄 추가
  다음: 문서 검토 후 수동 커밋 (이 스킬은 커밋하지 않는다)
```
