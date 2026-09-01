# dissect-builtin — 내장 스킬 해부

**한 줄 요약** — Claude Code 내장 스킬 하나를 로드해
`claude/built-in-skills/<skill-name>/` 아래에 한국어 분석 문서 `README.md` 와
원문 그대로의 `PROMPT.md` 두 파일을 산출한다.

## 언제 쓰고 언제 안 쓰는가

| 상황 | 사용 여부 |
|------|-----------|
| 내장 스킬이 내부에서 무엇을 하는지 뜯어보고 기록하고 싶다 | 사용 |
| 내장 스킬의 원문 프롬프트를 보존하고 싶다 | 사용 |
| **설치한 플러그인**을 문서화하고 싶다 | 사용 금지 — `harness:plugin-guide` |
| 내가 만든 `SKILL.md` 를 점검하고 싶다 | 사용 금지 — `skill:check` |
| 스킬을 새로 만들고 싶다 | 사용 금지 — `skill:create` |

`plugin-guide` 가 **설치된 플러그인의 캐시된 SKILL.md** 를 읽는 데 비해,
이 스킬은 **내장 스킬의 런타임 프롬프트** 를 대상으로 한다. 소스가 다르다.

## 호출 형식

```
/harness:dissect-builtin <skill-name>
/harness:dissect-builtin -h
```

| 인자 | 설명 | 필수 |
|------|------|------|
| `<skill-name>` | 해부할 내장 스킬 이름 (예: `keybindings-help`) | 예 |
| `-h`, `--help` | `references/help.md` 를 그대로 출력하고 중단 | — |

## 동작 단계

1. **스킬 프롬프트 로드** — `Skill(skill: "<skill-name>")` 로 대상 내장 스킬을
   로드한다. 주입된 원문 전체를 그대로 보존한다.
2. **에이전트 2개 병렬 실행** — 한 메시지에서 동시에 띄운다.

   | 에이전트 | 산출물 | 형식 |
   |----------|--------|------|
   | Agent 1 | `claude/built-in-skills/<name>/README.md` | 한국어 분석 문서 |
   | Agent 2 | `claude/built-in-skills/<name>/PROMPT.md` | 원문 그대로 |

   README.md 는 한줄 요약 → 동작 단계(Phase) → 상세 체크 항목 → 특징 순으로
   쓰되, 대상 스킬의 실제 흐름에 맞게 제목을 조정한다. 고정 템플릿을 억지로
   맞추지 않는다.
3. **완료 확인** — 두 에이전트가 끝나면 `[OK] harness:dissect-builtin` 과
   함께 스킬명, 산출 경로 2개, 다음 단계(`/gh:commit`)를 출력한다.

## 주의사항 / 제약

- **`PROMPT.md` 는 원문의 정확한 복사본이어야 한다.** 요약·번역·재포맷 금지.
- `README.md` 는 한국어로 쓴다. 영어는 기술 용어에만 쓴다.
- 산출 파일 이름으로 **`SKILL.md` 를 쓰지 않는다** — Claude Code 의 스킬
  로딩 메커니즘과 충돌한다.
- 대상이 내장 스킬이 아니어서 로드에 실패하면 사용자에게 알리고 대안을
  제시한다.
- 어느 단계에서든 오류가 나면 즉시 멈추고 `[FAIL]` 판정을 낸다 — 실패한
  Step 과 원인을 함께 보고한다.
