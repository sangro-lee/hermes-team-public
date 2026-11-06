#!/usr/bin/env bash
# 남에게 줄 "배포용" 연구실 묶음을 만든다 / 갱신한다. 지금 쓰는 hermes-team 폴더는 건드리지 않는다.
#   결과: ~/Projects/hermes-team-share/      (배포용 폴더, 이름은 <유저> 자리표시)
#         ~/Projects/hermes-team-share.tar   (이 파일을 그대로 주면 된다. 풀면 hermes-team/ 이 생김)
#   빼는 것: git 기록, 내 Discord ID(team.json·_team_ids.md), 내 프로젝트 목록, logs/·state/·memories/, commit 안 된 파일, 슬라이드(pptx), *.bak, 캐시
#   바꾸는 것: SOUL·템플릿의 연구자 이름 → <유저>, 예시 경로의 홈 경로 → /home/<사용자>
# SOUL·템플릿·스크립트를 고친 뒤 배포본도 최신으로 하고 싶을 때만 다시 실행한다.
# 사용: bash tools/make_handover.sh
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$(dirname "$SRC")/hermes-team-share"
TAR="$(dirname "$SRC")/hermes-team-share.tar"
PLACEHOLDER="<유저>"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -r "$SRC" "$TMP/hermes-team"
cd "$TMP/hermes-team"
rm -rf .git tools/__pycache__ logs state memories   # 실행 기록·인계 노트·기억(내 프로젝트·연구자 정보)은 빼고 준다
# commit 안 된 파일(작업 중인 것)은 빼고, commit된 것만 준다
git -C "$SRC" ls-files --others --exclude-standard -z | xargs -0 -r rm -f --
# 슬라이드(pptx)는 연구자 이름이 들어 있고 글자 치환이 안 되므로 뺀다
rm -f docs/*.pptx && rmdir docs 2>/dev/null || true
find . -name '*.bak' -delete
echo '[]' > projects.json
cp extras/team.example.json team.json
cp extras/_team_ids.example.md souls/_team_ids.md
cp extras/README_FIRST.md README_FIRST.md
sed -i -E 's#/home/[A-Za-z0-9._-]+/Projects#/home/<사용자>/Projects#g' souls/*.md
# 연구자 이름 → <유저>  (rename 은 새 이름에 < > 를 막으므로 직접 치환)
OLD="$(grep -oP '연구자\s+\K[^\s:`]+' souls/_team_ids.md | head -1)"
if [[ -n "$OLD" && "$OLD" != "$PLACEHOLDER" ]]; then
  grep -rlF -- "$OLD" souls newproject.py extras template tools INSTALL.md SETUP.md | xargs -r sed -i "s/${OLD}/${PLACEHOLDER}/g"
fi

# 남은 개인 흔적 점검 (Discord ID 형태의 긴 숫자, 홈 경로)
LEFT=$(grep -rnE '\b[0-9]{17,20}\b|/home/[A-Za-z0-9._-]+/' --exclude='*.pptx' --exclude=INSTALL.md . | grep -v '/home/<사용자>/' || true)
if [[ -n "$LEFT" ]]; then echo "확인 필요 (개인 정보일 수 있음):"; echo "$LEFT"; fi

# 배포 폴더는 GitHub(hermes-lab)와 연결된 git 저장소다. .git은 살려 두고 내용만 바꾼다
[[ -d "$DEST/.git" ]] && mv "$DEST/.git" "$TMP/share.git"
rm -rf "$DEST" && cp -r "$TMP/hermes-team" "$DEST"
[[ -d "$TMP/share.git" ]] && mv "$TMP/share.git" "$DEST/.git"
(cd "$TMP" && tar cf "$TAR" hermes-team)
echo "배포용 폴더: $DEST"
echo "배포용 파일: $TAR ($(du -h "$TAR" | cut -f1))  ← 이걸 그대로 주면 된다"
[[ -d "$DEST/.git" ]] && echo "GitHub 반영: cd $DEST && git add -A && git commit -m \"<내용>\" && git push"
echo "받는 사람: tar 풀기 → bash set_name.sh <이름> → INSTALL.pdf  (README_FIRST.md 참고)"
