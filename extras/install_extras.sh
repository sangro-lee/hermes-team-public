#!/usr/bin/env bash
# 자동 장치 일괄 설치 (여러 번 실행해도 된다. extras/를 고친 뒤에도 이걸 다시 돌린다):
#   - cron 스크립트(아침 브리핑·차단 감시·PI 인계) → ~/.hermes/scripts/  (cron은 심볼릭 링크를 거부해서 복사,
#     복사하면서 {{연구자}}를 souls/_team_ids.md 의 이름으로 채운다)
#   - hook pi-handoff → ~/.hermes/hooks/,  플러그인 lab-handoff → ~/.hermes/plugins/ + enable
#   - cron 등록: morning-brief(09:00), block-watch(10분마다). 같은 이름이 이미 있으면 건너뛴다
# 끝나면 게이트웨이를 재시작해야 hook·플러그인이 켜진다 (bash install_souls.sh 가 재시작까지 한다).
set -euo pipefail
EX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$HOME/.hermes"

IDS="$EX/../souls/_team_ids.md"
NAME="$(grep -oP '^\s*-\s*연구자\s+\K[^\s:`]+' "$IDS" 2>/dev/null | head -1)"
[[ -n "$NAME" ]] || { echo "ERROR: $IDS 에 연구자 이름이 없습니다. 먼저: bash set_name.sh <내이름>"; exit 1; }

mkdir -p "$H/scripts" "$H/hooks" "$H/plugins"
for f in morning-brief.sh block-watch.sh pi-handoff.sh; do
  sed "s/{{연구자}}/${NAME}/g" "$EX/$f" > "$H/scripts/$f"
  chmod +x "$H/scripts/$f"
done
rm -rf "$H/hooks/pi-handoff" "$H/plugins/lab-handoff"
cp -r "$EX/hooks/pi-handoff" "$H/hooks/"
cp -r "$EX/plugins/lab-handoff" "$H/plugins/"
hermes plugins enable lab-handoff >/dev/null
echo "복사: scripts 3개 (연구자 이름 $NAME), hook pi-handoff, plugin lab-handoff (enabled)"

jobs=$(hermes cron list 2>/dev/null | awk '/Name:/ {print $2}')
add_job() {   # $1=이름 $2=일정 $3=스크립트
  if grep -qx "$1" <<<"$jobs"; then echo "cron $1: 이미 있음"; return; fi
  hermes cron create "$2" --script "$3" --no-agent --name "$1" --workdir "$HOME/Projects" --deliver discord >/dev/null
  echo "cron $1: 등록 ($2)"
}
add_job morning-brief "0 9 * * *" morning-brief.sh
add_job block-watch "*/10 * * * *" block-watch.sh
hermes cron list 2>/dev/null | grep -E "Name:|Next run:"
echo "다음: bash ~/Projects/hermes-team/install_souls.sh  (재시작 → hook·플러그인 적용)"
