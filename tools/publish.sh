#!/usr/bin/env bash
# 공개 저장소(hermes-team-public)를 지금 main 상태로 갱신한다. 공개 쪽에는 commit 기록 없이 "최신 1개"만 남는다.
#   - main 에 commit된 파일만 보낸다 (commit 안 한 수정, .gitignore 파일은 빠짐). 먼저 commit 해 둘 것
#   - 보내기 전에 개인 정보(내 이름, /home/<나>, Discord ID 형태 숫자, 내 PC 전용 파일)를 검사하고, 있으면 멈춘다
#   - 공개 저장소는 매번 통째로 덮어쓴다 (push -f)
# 사용: bash tools/publish.sh [-y]          -y: 확인 질문 없이 바로 보낸다
#   주소를 바꾸려면: HERMES_PUBLIC_URL=https://github.com/<계정>/<저장소>.git bash tools/publish.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 기본 주소: 개발용 저장소(origin) 주소의 hermes-team → hermes-team-public
URL=${HERMES_PUBLIC_URL:-$(git -C "$ROOT" remote get-url origin | sed -E 's#/hermes-team(\.git)?$#/hermes-team-public.git#')}
YES=0; [[ ${1:-} == -y ]] && YES=1
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cd "$ROOT"
rev=$(git rev-parse --short main)
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || echo "[publish] 참고: commit 안 한 수정이 있습니다. 공개판에는 들어가지 않습니다 (main $rev 기준)."
git archive main | tar -x -C "$TMP"

# 개인 정보 검사 (pre-commit hook 과 같은 기준)
name=$(grep -oP '^\s*-\s*연구자\s+\K[^\s:`]+' souls/_team_ids.md 2>/dev/null | head -1 || true)
pat="/home/${USER}\b|\b[0-9]{17,20}\b"
[[ -n "$name" && "$name" != "<유저>" ]] && pat="$pat|$name"
cd "$TMP"
private=$(find . -path ./.git -prune -o -type f -print | sed 's#^\./##' \
  | grep -E '^(team\.json|projects\.json|souls/_team_ids\.md|memories/)|\.pptx$' || true)
hits=$(grep -rnE --exclude='*.example.*' --exclude='_team_ids.example.md' --exclude='*.pdf' --exclude='*.png' "$pat" . \
  | sed -E 's/\b([0-9])\1{16,19}\b/<예시ID>/g' | grep -E "$pat" | head -n 10 || true)
if [[ -n "$private$hits" ]]; then
  echo "[publish] 멈춤: 공개하면 안 되는 것이 있습니다."
  [[ -n "$private" ]] && echo "$private" | sed 's/^/    파일: /'
  [[ -n "$hits" ]] && echo "$hits" | sed 's/^/    /'
  exit 1
fi

files=$(find . -type f | wc -l)
echo "[publish] main $rev → $URL"
echo "[publish] 파일 ${files}개, 개인 정보 검사 통과. 공개 저장소를 이 내용으로 덮어씁니다."
if [[ $YES -eq 0 ]]; then
  read -r -p "보낼까요? [y/N] " a
  [[ $a == [yY] ]] || { echo "[publish] 취소"; exit 0; }
fi
git init -q -b main
git add -A
git -c core.hooksPath=/dev/null commit -q -m "Hermes AI 연구실 $(date +%Y-%m-%d) (main $rev)"
git push -q -f "$URL" main
echo "[publish] 완료: ${URL%.git}"
