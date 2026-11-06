---
name: research-analysis
description: 실험이 끝난 뒤 결과를 baseline과 비교해 요약하고, 관찰·해석·한계를 구분한 FINDINGS.md 수정안을 만든다. 실험 결과 분석이나 연구 기록 갱신을 요청받았을 때 사용.
---

# Skill: Research Result Analysis

## Purpose
실험 결과를 일관된 형식으로 요약하고, 관찰과 해석을 구분한다.

## Inputs
- 실험 명세 (`experiments/<id>.yaml`)
- 로그 파일 경로
- metric 결과 파일 (`results/<id>/metrics.json`)
- baseline 결과

## Procedure
1. 실험 ID와 명세를 확인한다.
2. 종료 코드와 로그에서 오류를 확인한다.
3. metric 계산이 명세의 정의와 일치하는지 확인한다.
4. baseline과 동일한 조건인지 확인한다.
5. 명세의 `success_criteria`를 하나씩 대조해 충족/미충족을 표시한다.
6. 관찰·해석·한계를 별도 항목으로 작성한다.
7. `results/<id>/summary.md`를 작성한다.
8. `research/FINDINGS.md`와 `research/RESEARCH_STATE.md` 수정안을 **diff로 제시**하고 승인을 기다린다.

## Output
- 짧은 요약
- 핵심 metric과 baseline 비교 표
- success_criteria 충족 여부
- 실패/경고
- 재현 정보 (commit, seed, 명령어)
- 다음으로 확인할 질문

## Safety
- 원본 데이터나 체크포인트를 삭제하지 않는다.
- 수치가 없는 결론을 사실처럼 쓰지 않는다.
- 검토되지 않은 해석은 가설로 표시한다.
- 연구자 승인 전에는 `research/` 파일을 덮어쓰지 않는다.
