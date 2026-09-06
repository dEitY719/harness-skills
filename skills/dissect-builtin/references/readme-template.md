# README.md brief

The brief Step 2's agent gets. It analyzes the prompt loaded in Step 1 and
writes `docs/built-in-skills/<skill-name>/README.md` in Korean.

## Required content

1. **한줄 요약**: 스킬이 하는 일을 한 문장으로
2. **동작 단계(Phase)**: 스킬이 수행하는 단계별 흐름
3. **상세 체크 항목**: 각 단계에서 확인하는 구체적 항목 (있는 경우)
4. **특징**: 주목할 만한 설계 특성 (병렬 실행, 쓰기 권한, 특정 도메인 특화 등)

Use summary tables where appropriate.

## Suggested heading chain

```
# /<skill-name> - <Title>
한줄 설명 (내장 스킬임을 명시)
## 동작 요약
## Phase N: ...
## 특징
```

Adapt the headings to the skill's actual phases — do not force a fixed
template. Korean prose throughout; English only for technical terms.
