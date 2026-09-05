# harness-refactor.js — 워크플로우 파일 구조

Step 3 에서 생성할 파일의 필수 구조.

## 상수 정의 (필수)

```js
export const meta = {
  name: 'harness-refactor',
  description: 'Apply low-risk harness improvements identified in the latest audit',
  phases: [
    { title: 'Pre-flight',     detail: 'Verify target files exist, create archive directory' },
    { title: 'Apply Changes',  detail: 'Parallel agents modify non-overlapping file groups' },
    { title: 'Verify',         detail: 'Line count validation on all modified files' },
    { title: 'Final Report',   detail: 'Change summary, behavior delta, smoke-test prompts' },
  ],
}

const ARCHIVE = '.claude/archive/harness-refactor-YYYY-MM-DD'
const SKILLS  = '.claude/skills'
const ROOT    = '.'
```

워크플로우 런타임에는 파일시스템·셸 접근도 `process` 도 없다. 따라서 경로는
평범한 프로젝트 상대 문자열로 적고, 실제 해석은 스폰된 에이전트가 프로젝트
작업 디렉토리 기준으로 수행한다.

날짜(`YYYY-MM-DD`)는 오늘 날짜로 고정한다.

## 설계 원칙

- 각 에이전트는 비중첩 파일 그룹 담당, `CHANGE_SCHEMA` 로 구조화된 결과 반환
- Pre-flight: 대상 파일 존재 여부 확인 + archive 디렉토리 생성 (파일 수정 없음)
- Apply Changes: `parallel()` 병렬 에이전트, 아카이브 후 수정
- Verify: `wc -l` 비교 + references/ 파일 생성 확인
- Final Report: 변경 목록·이유·behavior delta·smoke-test 5개·Human Approval Required 섹션
