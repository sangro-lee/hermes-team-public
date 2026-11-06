# Experiments

실험은 한 개의 명세 파일과 연결된 실행 로그·결과로 추적합니다.

권장 규칙:
- ID 예: `vqc_mlp_seed42_001`
- 실행 전 명세를 작성하고 검증합니다.
- 승인 상태가 `approved`가 아니면 GPU 작업을 제출하지 않습니다.
- 명세에 Git commit, 데이터 버전, seed, metric, 성공 기준을 반드시 남깁니다.
- 실행 후에는 `results/<experiment_id>/`에 요약·로그 경로·metric을 기록합니다.

이 폴더에는 실제 실험을 자동 제출하는 기능이 없습니다.
