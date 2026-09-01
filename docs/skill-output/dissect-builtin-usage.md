# dissect-builtin 사용 결과

> **한 줄 요약** — 내장 스킬 이름 하나를 받아 한국어 분석 문서와 원문 프롬프트
> 사본 두 파일을 생성합니다.

```
내장 스킬 프롬프트  ──▶  /harness:dissect-builtin  ──▶  README.md + PROMPT.md
```

## 1. 실행한 명령

```
/harness:dissect-builtin <skill-name>          # 범용 형식
/harness:dissect-builtin keybindings-help      # 이번에 실행한 명령
```

## 2. 입력

Claude Code 내장 스킬 `keybindings-help` 의 런타임 프롬프트.
Step 1 에서 `Skill(skill: "keybindings-help")` 로 로드했다. 내용은
`~/.claude/keybindings.json` 편집 규칙 — 파일 포맷, 키스트로크 문법,
기본 바인딩 해제, 검증 이슈표, 예약 단축키, 컨텍스트/액션 목록.

## 3. 결과

Step 2 의 에이전트 2개가 병렬로 아래 두 파일을 썼다. 출력 루트는 dotfiles
저장소 대신 이번 실행용 샌드박스를 썼다(이 저장소를 오염시키지 않기 위해).

| 산출물 | 경로 | 줄 수 |
|--------|------|-------|
| README.md | `/tmp/claude-1000/-home-bwyoon-para-project-skills-harness-skills-feat-1/2b41ddbe-5bd8-4644-9057-9695525651e0/scratchpad/dissect-run/claude/built-in-skills/keybindings-help/README.md` | 98 |
| PROMPT.md | `/tmp/claude-1000/-home-bwyoon-para-project-skills-harness-skills-feat-1/2b41ddbe-5bd8-4644-9057-9695525651e0/scratchpad/dissect-run/claude/built-in-skills/keybindings-help/PROMPT.md` | 295 |

README.md 구성: 동작 요약 → 1단계 읽기 선행과 병합 → 2단계 키스트로크 문법
→ 3단계 바인딩 정의와 해제 → 4단계 검증과 경고 확인 → 상세 체크 항목
(검증 이슈 6종 / 예약 단축키 / 동작 규칙 5개) → 특징.

원문에서 직접 센 수치: 컨텍스트 20개, 액션 122개. PROMPT.md 는 첫 줄
`# Keybindings Skill`, 마지막 줄 `| \`selection:extendLineEnd\` | \`shift+end\` | Scroll |`
로 원문과 일치한다.

```
[OK] harness:dissect-builtin
  Skill:    keybindings-help
  Outputs:  claude/built-in-skills/keybindings-help/README.md
            claude/built-in-skills/keybindings-help/PROMPT.md
```
