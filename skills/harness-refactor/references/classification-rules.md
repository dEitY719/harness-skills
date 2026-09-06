# harness-refactor 변경 분류 규칙

Step 2 에서 감사 리포트 항목을 분류할 때 적용한다.

## 출력 형식

허용 변경으로 분류한 항목은 `{ file, description }` 객체의 배열로 정리한다.
`file` 은 대상 파일의 프로젝트 상대 경로, `description` 은 워크플로우의
Apply Changes 에이전트가 그대로 실행할 수 있는 구체적 지시문이다. 이 배열이
Step 3 의 `Workflow` 호출에 `args.changes` 로 그대로 전달된다.

## 허용 변경 (워크플로우에 포함)

- CLAUDE.md / AGENTS.md 에서 중복·일반론 섹션 제거
- 특정 작업 절차를 전역 지침에서 skill 로 이동
- 긴 SKILL.md 를 SKILL.md + references/ 구조로 분리
- Skill description/trigger 명확화
- settings.json 의 stale 권한 항목 제거
- 삭제 대상은 영구 삭제 없이 `.claude/archive/harness-refactor-YYYY-MM-DD/` 로 이동

## 절대 금지 (human review 목록으로만 기록)

- hooks 수정
- MCP 설정 변경
- allowed-tools 권한 확대
- 프로젝트 애플리케이션 코드 수정
- 테스트·빌드·배포 명령 실행
- 신뢰도 low 항목
