# plots/

실험 결과 그림 스크립트. analyst가 정하고 Claude Code가 작성한다.

- 파일명: `plot_<experiment_id>.py`
- 입력: `results/<experiment_id>/` 의 파일만 읽는다 (실험 재실행·숫자 재계산 금지)
- 출력: `results/<experiment_id>/figures/fig<번호>_<내용>.png` + `.pdf`, 설명은 같은 폴더 `captions.md`
- 실행: `uv run python plots/plot_<experiment_id>.py`
