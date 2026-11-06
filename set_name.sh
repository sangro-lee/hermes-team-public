#!/usr/bin/env bash
# 연구자 이름을 정한다. 내 PC 전용 설정 파일이 없으면 예시에서 만든다 (team.json, souls/_team_ids.md, projects.json).
# 이 파일들은 git에 올라가지 않는다. 원본 SOUL·템플릿의 {{연구자}} 는 설치할 때 이 이름으로 채워진다.
# 사용: bash set_name.sh <내이름>      예) bash set_name.sh minji   /   bash set_name.sh 김민지
# 직원들이 Discord에서 이 이름으로 나를 부르고 승인을 요청한다. 공백 없이 쓴다. 나중에 다시 실행해도 된다.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
if [[ $# -ne 1 ]]; then
  echo "사용: bash set_name.sh <내이름>   (지금: $(grep -oP '연구자\s+\K[^\s:`]+' souls/_team_ids.md | head -1))"
  exit 1
fi
[[ -f souls/_team_ids.md ]] || cp extras/_team_ids.example.md souls/_team_ids.md
[[ -f team.json ]] || cp extras/team.example.json team.json
[[ -f projects.json ]] || echo '[]' > projects.json
python3 tools/lab.py rename "$1"
git rev-parse --git-dir >/dev/null 2>&1 && git config core.hooksPath tools/git-hooks   # commit 전 개인 정보 검사
if [[ -f "$HOME/.hermes/SOUL.md" ]]; then
  echo "이미 설치한 상태라면: bash extras/install_extras.sh && bash install_souls.sh"
else
  echo "다음: INSTALL.pdf 를 처음부터 따라 한다."
fi
