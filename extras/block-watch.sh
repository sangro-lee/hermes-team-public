#!/usr/bin/env bash
# 차단 감시: 같은 카드가 2번 이상 block됐거나 triage로 가면 Claude가 원인을 진단하고 **허용 범위 안의 해결은 바로 한다.**
# 결과(원인·한 일·검증·{{연구자}} 결정 필요)를 그대로 Discord로 보낸다. PI의 판단을 거치지 않는다.
# hermes cron --no-agent 로 10분마다 실행. 새로 진단할 카드가 없으면 아무것도 출력하지 않는다 (전송 안 됨).
# 같은 카드는 block 횟수가 늘었을 때만 다시 본다 (logs/block-watch/<board>-<id>.done).
# 같은 카드의 자동 해결은 MAX_FIXES번까지. 그 뒤로는 진단만 하고 {{연구자}}에게 넘긴다 (<board>-<id>.fixes).
set -u
export PATH="$HOME/.local/bin:$PATH"
MIN_BLOCKS=${MIN_BLOCKS:-2}
MAX_FIXES=${MAX_FIXES:-2}

logd="$HOME/Projects/hermes-team/logs/block-watch"
mkdir -p "$logd"
exec 9>"$logd/.lock"
flock -n 9 || exit 0
cd "$HOME/Projects" || exit 1

read_tools="Read,Glob,Grep,Bash(hermes kanban:*),Bash(git status:*),Bash(git log:*),Bash(git show:*),Bash(git diff:*),Bash(git branch --show-current),Bash(tail:*),Bash(ps:*),Bash(bash scripts/researchctl doctor:*),Bash(bash scripts/researchctl validate:*)"
fix_tools="$read_tools,Edit,Write,Bash(git add:*),Bash(git commit:*),Bash(git update-index:*)"
# 연구 기록·결과·코드·Hermes 설정은 자동 해결 대상이 아니다
deny_tools="Edit(research/**),Edit(results/**),Edit(src/**),Edit(~/.hermes/**),Bash(git push:*),Bash(git checkout:*),Bash(git switch:*),Bash(git reset:*),Bash(git branch -:*)"

for b in $(hermes kanban boards list 2>/dev/null | awk 'NR>1 && NF>=2 && $1!="Current" && $1!="Switch" {s=$1; if (s=="●") s=$2; print s}'); do
  case "$b" in default|demo-*|torch-*) continue ;; esac
  repo="$HOME/Projects/$b"
  [ -d "$repo/.git" ] || continue
  for st in blocked triage; do
    for id in $(hermes kanban --board "$b" list --status "$st" 2>/dev/null | grep -o 't_[0-9a-f]\{8\}'); do
      show=$(hermes kanban --board "$b" show "$id" 2>&1)
      n=$(grep -cE '^ *#[0-9]+ +blocked' <<<"$show")
      [ "$st" = triage ] || [ "$n" -ge "$MIN_BLOCKS" ] || continue
      mark="$logd/$b-$id.done"
      [ "$(cat "$mark" 2>/dev/null)" = "$st:$n" ] && continue

      fixes=$(cat "$logd/$b-$id.fixes" 2>/dev/null || echo 0)
      branch=$(git -C "$repo" branch --show-current)
      mode=fix
      [ "$fixes" -ge "$MAX_FIXES" ] && mode=diagnose
      [ "$branch" = main ] || mode=diagnose   # main이 아니면 commit하지 않는다

      name="$id-$(date +%H%M)"
      mkdir -p "$repo/docs/diagnosis"
      pf="$repo/docs/diagnosis/$name.prompt.txt"
      log="$repo/docs/diagnosis/$name.log"
      head_before=$(git -C "$repo" rev-parse HEAD)
      dirty_before=$(git -C "$repo" status --short -- research results src experiments)
      {
        echo "칸반 카드 $id (board $b, 프로젝트 폴더 $repo)가 지금 $st 상태이고, 지금까지 ${n}번 block됐다."
        echo "카드 기록 (hermes kanban --board $b show $id 끝부분):"
        tail -n 150 <<<"$show"
        echo
        echo "1) 왜 같은 카드가 반복해서 막히는지 원인을 로그 근거(파일:줄 또는 명령 출력)와 함께 밝혀라."
        echo "   원인을 고치지 않은 채 카드를 다시 올린(unblock·specify·재배정) 사람이 있으면 누가 언제 그랬는지도 적어라."
        if [ "$mode" = fix ]; then
          cat <<'EOF'
2) 아래 '바로 해도 되는 것'에 해당하는 해결은 지금 직접 해라. 그 밖의 것은 하지 말고 '남은 것'으로 넘겨라.
   바로 해도 되는 것:
   - 실행 환경·명세 정합화: 실행 권한(git update-index --chmod), 이미 검토된 코드와 명세 사이의 기계적 불일치
     (예: experiments/*.yaml의 command를 코드에 고정된 명령과 글자까지 같게, code_commit을 실제 commit으로).
   - 카드 정리: 코멘트, 중복 카드 archive, 원인이 해결된 카드 unblock, 코드 수정이 필요하면 coder 카드 생성.
   - 위 변경의 git commit (main, 메시지 앞에 "block-watch: ", 바뀐 파일만 git add).
   절대 하지 않는 것:
   - experiments/*.yaml의 approval(status·approved_by·approved_at·pending_gates) 변경, 승인이 없는데 승인된 것처럼 만드는 일.
   - research/·results/·src/ 수정, 실험·preflight 실행, 브랜치 생성·전환, push, 파일 삭제, Hermes 설정·SOUL 수정.
   - 연구 내용 판단(가설·해석·수치)이 필요한 수정.
   unblock은 원인을 고쳤고 doctor·validate가 통과했을 때만 한다. 확신이 없으면 고치지 말고 '남은 것'으로 넘겨라.
3) 출력은 한국어, 1500자 이내, 형식: 원인 / 근거 / 한 일 (commit 해시·명령) / 검증 / 남은 것 (누가·무엇을) / {{연구자}} 결정 필요.
EOF
        else
          echo "2) 파일과 카드는 건드리지 마라 (이 카드는 자동 해결을 이미 ${fixes}번 했거나 main 브랜치가 아니다: 지금 '$branch')."
          echo "   해결 방법을 누가({{연구자}} / PI / 담당 직원) 무엇을 해야 하는지와 실행할 명령으로 제안하라."
          echo "3) 출력은 한국어, 1200자 이내, 형식: 원인 / 근거 / 해결 (누가·명령) / {{연구자}} 결정 필요."
        fi
      } > "$pf"
      if [ "$mode" = fix ]; then tools="$fix_tools"; else tools="$read_tools"; fi
      ( cd "$repo" && timeout 900 claude -p "$(cat "$pf")" --add-dir "$HOME/.hermes" \
          --allowedTools "$tools" --disallowedTools "$deny_tools" \
          --max-turns 40 --output-format text > "$log" 2>&1; echo "exit=$?" >> "$log" )

      if [ "$mode" = fix ]; then
        echo "🛠 [$b] $id 차단 자동 해결 (block ${n}회, 지금 $st, 자동 해결 $((fixes + 1))/$MAX_FIXES번째) — Claude"
        echo $((fixes + 1)) > "$logd/$b-$id.fixes"
      else
        echo "🔎 [$b] $id 차단 진단 (block ${n}회, 지금 $st) — Claude, 자동 해결 안 함 → {{연구자}} 판단 필요"
      fi
      if grep -q '^exit=0$' "$log"; then
        grep -v '^exit=' "$log" | head -c 3500 | iconv -c -f utf-8 -t utf-8   # 잘린 한글 바이트 제거
        echo "$st:$n" > "$mark"
      else
        echo "⚠ 실패: $(tail -n 3 "$log" | tr '\n' ' ')"   # mark를 남기지 않아 다음 실행에서 다시 시도한다
      fi
      # 사후 점검: 금지 범위가 바뀌었으면 크게 알린다 (되돌리지는 않는다)
      changed=$(git -C "$repo" diff --name-only "$head_before" HEAD -- research results src
                [ "$(git -C "$repo" status --short -- research results src experiments)" = "$dirty_before" ] || echo "(미커밋 변경 있음)")
      approval=$(git -C "$repo" diff "$head_before" HEAD -- 'experiments/*.yaml' | grep -E '^[+-] *(status|approved_by|approved_at|pending_gates)')
      [ -n "$changed" ] && echo "⚠ 금지 범위 변경 감지 (research/results/src): $(echo $changed)"
      [ -n "$approval" ] && echo "⚠ 승인 필드 변경 감지: $(echo $approval | head -c 300)"
      new_commits=$(git -C "$repo" log --format='%h %s' "$head_before"..HEAD)
      [ -n "$new_commits" ] && echo "commit: $(echo "$new_commits" | tr '\n' ';')"
      echo "로그: ${log#$HOME/}"; echo
    done
  done
done
