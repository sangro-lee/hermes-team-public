#!/usr/bin/env bash
# 아침 브리핑: 상태를 모아 Claude(읽기 전용)가 정리하고, 그 출력을 그대로 Discord로 보낸다.
# hermes cron --no-agent 로 실행된다 (PI 모델은 쓰지 않음). stdout = 보고 본문.
# 사용: morning-brief.sh [프로젝트]   — 프로젝트를 주면 그 보드·저장소만 본다 (Discord /brief 가 프로젝트 채널에서 쓴다)
set -u
only=${1:-}
export PATH="$HOME/.local/bin:$PATH"
cd "$HOME/Projects" || exit 1

out_dir="$HOME/Projects/hermes-team/logs/morning-brief"
mkdir -p "$out_dir"
stamp=$(date +%Y%m%d-%H%M)${only:+-$only}
ctx="$out_dir/$stamp.context.txt"

{
  echo "# 수집 시각: $(date '+%Y-%m-%d %H:%M %Z')"
  for b in $(hermes kanban boards list 2>/dev/null | awk 'NR>1 && NF>=2 && $1!="Current" && $1!="Switch" {s=$1; if (s=="●") s=$2; print s}'); do
    if [ -n "$only" ]; then [ "$b" = "$only" ] || continue
    else case "$b" in default|demo-*|torch-*) continue ;; esac; fi
    echo; echo "## board: $b"
    hermes kanban --board "$b" list --sort updated 2>&1 | head -n 40
    for st in blocked triage review; do
      for id in $(hermes kanban --board "$b" list --status "$st" 2>/dev/null | grep -o 't_[0-9a-f]\{8\}'); do
        echo; echo "### $st card $id (끝부분)"
        hermes kanban --board "$b" show "$id" 2>&1 | tail -n 40
      done
    done
  done
  for d in "$HOME"/Projects/*/; do
    [ -d "$d/.git" ] || continue
    p=$(basename "$d")
    if [ -n "$only" ]; then [ "$p" = "$only" ] || continue
    else case "$p" in hermes-team|demo-*|torch-*) continue ;; esac; fi
    echo; echo "## repo: $p"
    echo "### git status --short"; git -C "$d" status --short | head -n 30
    echo "### commits (24h)"; git -C "$d" log --since='24 hours ago' --format='%h %ad %s' --date=format:'%m-%d %H:%M' | head -n 30
    if [ -f "$d/research/RESEARCH_STATE.md" ]; then
      echo "### RESEARCH_STATE.md (앞부분)"; head -n 60 "$d/research/RESEARCH_STATE.md"
    fi
  done
} > "$ctx" 2>&1

prompt='아래는 오늘 아침 수집한 연구실 상태다 (칸반 보드, 막힌 카드 끝부분, git 상태, 최근 24시간 commit, RESEARCH_STATE 앞부분).
이것만 근거로 Discord에 보낼 아침 브리핑을 한국어로 짧게 써라. 추측하지 말고, 자료에 없는 것은 쓰지 마라.
형식:
1) 맨 위 "오늘 {{연구자}}가 할 일" 최대 3줄 (승인 대기, blocked 해제에 필요한 결정 등. 각 줄에 카드 ID).
2) 프로젝트별: 지난 24시간에 끝난 카드, running 카드, blocked/triage 카드(원인 한 줄 + 풀기 위한 다음 행동), review 대기. 표 또는 짧은 목록.
3) 커밋 안 된 변경이 있으면 한 줄.
변화 없는 프로젝트는 한 줄로만. 전체 1500자 이내. 인사말·맺음말 없이 본문만 출력하라.'
[ -n "$only" ] && prompt="$prompt
이번에는 프로젝트 $only 하나만 다룬다. 2)는 그 프로젝트만 쓰고, RESEARCH_STATE 기준으로 지금 단계와 다음 행동을 한 줄 덧붙여라."

result=$(timeout 600 claude -p "$prompt" --model sonnet --allowedTools "Read,Glob,Grep" \
  --max-turns 5 --output-format text < "$ctx" 2>&1)
code=$?
echo "$result" > "$out_dir/$stamp.brief.txt"

if [ $code -ne 0 ] || [ -z "$result" ]; then
  echo "⚠ 아침 브리핑: Claude 정리 실패 (exit=$code). 로그: $out_dir/$stamp.brief.txt"
  echo "$result" | tail -n 5
  exit 0
fi
echo "$result"
