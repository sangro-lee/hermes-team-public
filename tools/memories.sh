#!/usr/bin/env bash
# 직원 장기 기억(MEMORY.md·USER.md)을 hermes-team/memories/ 와 주고받는다.
#   export: ~/.hermes → memories/<profile>/   (git commit 전에 실행. 기억은 직원이 계속 고치므로 이게 최신본)
#   import: memories/<profile>/ → ~/.hermes   (새 PC 설치 후, 게이트웨이 재시작 전에 실행. 같은 이름 파일은 덮어쓴다)
# 사용: bash tools/memories.sh export | import
# 배포본(make_handover.sh)에는 넣지 않는다: 기억에는 내 프로젝트·연구자 정보가 들어 있다.
set -euo pipefail
TEAM="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 직원 목록은 team.json 의 "profiles" (없으면 기본 6명)
read -r -a PROFILES <<< "$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["profiles"]))' \
  "$TEAM/team.json" 2>/dev/null || echo "default coder analyst reviewer writer scholar")"

home_of() { [[ $1 == default ]] && echo "$HOME/.hermes/memories" || echo "$HOME/.hermes/profiles/$1/memories"; }

case "${1:-}" in
  export)
    for p in "${PROFILES[@]}"; do
      src=$(home_of "$p"); dst="$TEAM/memories/$p"
      mkdir -p "$dst"
      for f in MEMORY.md USER.md; do
        if [[ -s "$src/$f" ]]; then cp "$src/$f" "$dst/$f"; else rm -f "$dst/$f"; fi
      done
    done
    git -C "$TEAM" status --short -- memories
    ;;
  import)
    for p in "${PROFILES[@]}"; do
      src="$TEAM/memories/$p"; dst=$(home_of "$p")
      [[ -d "$src" ]] || continue
      [[ $p == default || -d "$HOME/.hermes/profiles/$p" ]] || { echo "건너뜀: profile $p 없음 (3-3 먼저)"; continue; }
      mkdir -p "$dst"
      for f in MEMORY.md USER.md; do
        [[ -s "$src/$f" ]] && cp "$src/$f" "$dst/$f" && echo "$p/$f"
      done
    done
    echo "가져옴. 게이트웨이를 재시작하면(install_souls.sh) 새 대화부터 반영된다."
    ;;
  *) echo "사용: bash tools/memories.sh export | import" >&2; exit 2 ;;
esac
