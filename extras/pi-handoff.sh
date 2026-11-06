#!/usr/bin/env bash
# PI 인계 노트: PI 대화가 압축될 때마다(hooks/pi-handoff) 호출된다.
# PI 대화 전체와 현재 보드·git 상태를 Claude(읽기 전용)가 읽고 state/pi-handoff.md를 다시 쓴다.
# 한 대화에서 인계 노트를 RESET_AFTER번 이상 썼으면(state/handoff-count) state/pi-reset-requested에 session_id를 남긴다 →
# plugins/lab-handoff가 다음 사용자 메시지에서 새 대화로 바꾸고, 새 대화 시스템 프롬프트에 인계 노트를 넣는다.
# 사용: pi-handoff.sh <session_id> [compression_count]
set -u
export PATH="$HOME/.local/bin:$PATH"
RESET_AFTER=${RESET_AFTER:-3}

sid=${1:?session_id}
count=${2:-0}
team="$HOME/Projects/hermes-team"
state="$team/state"
logd="$team/logs/handoff"
mkdir -p "$state" "$logd"

exec 9>"$state/.handoff.lock"
flock -w 900 9 || exit 0   # 앞 실행이 끝날 때까지 기다린다 (더 최신 대화로 다시 쓰기 위해)

stamp=$(date +%Y%m%d-%H%M%S)
work="$logd/$stamp"
mkdir -p "$work/full" "$work/user"
cd "$HOME/Projects" || exit 1

hermes sessions export --format md --session-id "$sid" "$work/full/" > "$work/export.log" 2>&1 || exit 0
hermes sessions export --format md --only user-prompts --session-id "$sid" "$work/user/" >> "$work/export.log" 2>&1
full=$(ls "$work"/full/*.md 2>/dev/null | head -n 1)
[ -n "$full" ] || exit 0

ctx="$work/context.txt"
{
  echo "# 작성 시각: $(date '+%Y-%m-%d %H:%M %Z') / PI 대화 $sid / 압축 ${count}회"
  echo; echo "## 이전 인계 노트"
  cat "$state/pi-handoff.md" 2>/dev/null || echo "(없음)"
  echo; echo "## 이 대화의 {{연구자}} 메시지 전체 (칸반 알림 포함)"
  cat "$work"/user/*.md 2>/dev/null | tail -c 120000
  echo; echo "## 이 대화의 최근 부분 (도구 출력 포함, 끝부분만)"
  tail -c 250000 "$full"
  for d in "$HOME"/Projects/*/; do
    [ -d "$d/.git" ] || continue
    p=$(basename "$d")
    case "$p" in hermes-team|demo-*|torch-*) continue ;; esac
    echo; echo "## repo: $p (현재)"
    echo "### 칸반"; hermes kanban --board "$p" list --sort updated 2>&1 | head -n 25
    echo "### commits (24h)"; git -C "$d" log --since='24 hours ago' --format='%h %ad %s' --date=format:'%m-%d %H:%M' | head -n 20
    echo "### git status --short"; git -C "$d" status --short | head -n 20
  done
} > "$ctx" 2>&1

prompt='아래는 연구실 PI 에이전트의 현재 대화 기록과 연구실 상태다. 이 대화는 곧 끝나고 PI는 새 대화에서 이 노트만 들고 일을 이어받는다.
PI가 이어서 일하는 데 필요한 것만 담은 인계 노트를 한국어 마크다운으로 써라. 전체 3000자 이내.
규칙:
- 자료에 있는 것만 쓴다. 추측하지 않는다. 카드 ID·commit·파일 경로를 그대로 적는다.
- {{연구자}}의 지시·승인·금지는 요약하지 말고 짧게 원문 인용한다(언제 했는지 시각 포함). 승인 기록이 없는 것을 승인됐다고 쓰지 않는다.
- 이전 인계 노트 중 아직 유효한 것은 남기고, 끝났거나 뒤집힌 것은 뺀다.
- 수치·결과 해석은 쓰지 않는다(FINDINGS ID나 결과 폴더만 가리킨다).
형식 (해당 없는 절은 "없음"):
## 진행 중인 {{연구자}} 지시
## 승인 상태 (받은 승인 / 대기 중인 승인)
## 카드별 상태 (ID, 담당, 상태, 막힌 횟수와 원인, 다음 행동)
## 하지 말 것 ({{연구자}}가 금지한 것, 반복된 실수)
## 다음에 먼저 확인할 것
인사말·설명 없이 노트 본문만 출력하라.'

out=$(timeout 900 claude -p "$prompt" --model sonnet --allowedTools "Read,Glob,Grep" \
  --max-turns 5 --output-format text < "$ctx" 2>"$work/claude.err")
code=$?
printf '%s\n' "$out" > "$work/handoff.md"
if [ $code -ne 0 ] || [ ${#out} -lt 200 ]; then
  echo "claude 실패 exit=$code" >> "$work/claude.err"
  exit 0   # 실패하면 이전 노트를 그대로 두고, 새 대화 요청도 하지 않는다
fi

printf '%s\n' "$out" > "$state/pi-handoff.md.tmp" && mv "$state/pi-handoff.md.tmp" "$state/pi-handoff.md"
# hermes의 compression_count는 게이트웨이 재시작·agent 재생성 때 0으로 돌아가므로 대화별로 직접 센다
prev=$(awk -v s="$sid" '$1==s {print $2}' "$state/handoff-count" 2>/dev/null)
n=$(( ${prev:-0} + 1 ))
[ "$count" -gt "$n" ] && n=$count
echo "$sid $n" > "$state/handoff-count"
if [ "$n" -ge "$RESET_AFTER" ]; then
  echo "$sid" > "$state/pi-reset-requested"
fi
rm -rf "$work/full" "$work/user"   # 대화 원본은 hermes에 남아 있으므로 지운다
