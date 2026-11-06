#!/usr/bin/env bash
# gnode1 → 계산노드 실행 도우미. /home(NFS)은 지나가는 곳으로만 쓰고, 계산은 계산노드 로컬 디스크에서 한다.
#   1) gnode1에서 uv 환경을 만들어 묶음 하나로 /home 에 둔다 (패키지가 바뀔 때만)
#   2) 코드를 /home 에 올리고 sbatch → 계산노드가 로컬로 복사해 계산, out/ 만 /home 에 돌려놓는다
#   3) fetch 가 결과를 gnode1 /data 로 옮기고 /home 을 비운다
#
# 사용 (gnode1에서):
#   bash tools/hpc.sh run    <프로젝트폴더> "<실행 명령>" [sbatch 옵션...]   제출 → 끝날 때까지 기다림 → 결과 가져오기
#   bash tools/hpc.sh submit <프로젝트폴더> "<실행 명령>" [sbatch 옵션...]   제출만 (긴 job)
#   bash tools/hpc.sh status                     실행 중인 job과 가져올 결과
#   bash tools/hpc.sh fetch <jobid|all>          끝난 job 결과를 /data 로 가져오고 /home 을 비운다
#   bash tools/hpc.sh env <프로젝트폴더>          환경 묶음만 미리 만든다
#   예) bash tools/hpc.sh run ~/Projects/uvtest "python gpu.py" -p a5k1 --gres=gpu:1 -t 01:00:00
#
# 규칙: 실행 명령은 프로젝트 복사본 폴더에서 돈다. out/ 에 쓴 것만 돌아온다. 화면 출력은 out/run.log.
#       프로젝트에는 pyproject.toml 이 있어야 한다 (uv init). 계산노드는 인터넷이 없어도 된다.
set -euo pipefail

STAGE=${HPC_STAGE:-/home/$USER/hpc}                     # NFS: 잠깐 거쳐 가는 곳
RESULTS=${HPC_RESULTS:-/data/$USER/results}     # gnode1: 결과 도착
NODE_ROOT=${HPC_NODE_ROOT:-/var/tmp/$USER}              # gnode1·계산노드 공통 로컬 경로 (환경은 같은 경로라야 동작)
MIN_FREE_GB=${HPC_MIN_FREE_GB:-20}                      # 계산노드 로컬 디스크가 이보다 적으면 시작하지 않음
KEEP_ENVS=2                                             # 프로젝트마다 남겨 둘 환경 묶음 수
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[hpc] $*" >&2; }
die() { echo "[hpc] 오류: $*" >&2; exit 1; }

# ------------------------------------------------------------------ env
env_build() {   # $1=프로젝트 폴더 → 환경 이름(<프로젝트>-<해시>)을 출력
  local dir proj hash name tarball envdir
  dir=$(cd "$1" && pwd)
  [[ -f $dir/pyproject.toml ]] || die "$dir/pyproject.toml 없음 (먼저: cd $dir && uv init)"
  (cd "$dir" && uv lock -q)
  proj=$(basename "$dir")
  hash=$(cat "$dir/uv.lock" "$dir/.python-version" 2>/dev/null | sha256sum | cut -c1-12)
  name=$proj-$hash
  tarball=$STAGE/envs/$name.tar.gz
  if [[ -f $tarball ]]; then
    log "환경 묶음 그대로 씀: $tarball"
    echo "$name"; return
  fi
  envdir=$NODE_ROOT/env/$name
  log "환경 만들기: $envdir"
  rm -rf "$envdir"; mkdir -p "$envdir" "$STAGE/envs"
  (cd "$dir" && UV_PYTHON_PREFERENCE=only-managed UV_PYTHON_INSTALL_DIR=$envdir/python \
      UV_PROJECT_ENVIRONMENT=$envdir/venv UV_LINK_MODE=copy \
      uv sync --frozen --no-install-project -q) >&2
  log "묶기: $tarball"
  tar -czf "$tarball.part" -C / "${envdir#/}"
  mv "$tarball.part" "$tarball"
  ls -t "$STAGE/envs/$proj-"????????????.tar.gz | tail -n +$((KEEP_ENVS + 1)) | xargs -r rm -f
  echo "$name"
}

# ------------------------------------------------------------------ submit
submit() {   # $1=프로젝트 폴더, $2=실행 명령, 나머지=sbatch 옵션 → job 번호 출력
  [[ $# -ge 2 ]] || die "사용: hpc.sh submit <프로젝트폴더> \"<실행 명령>\" [sbatch 옵션...]"
  local dir cmd name envname tag in jobid
  dir=$(cd "$1" && pwd); cmd=$2; shift 2
  envname=$(env_build "$dir")
  name=$(basename "$dir")
  tag=$name-$(date +%m%d-%H%M%S)-$$
  in=$STAGE/in/$tag
  mkdir -p "$in/.hpc" "$STAGE/logs" "$STAGE/jobs"
  log "코드 올리기: $in"
  rsync -a --exclude .venv --exclude .git --exclude out --exclude __pycache__ --exclude '*.pyc' \
      "$dir/" "$in/"
  printf '%s\n' "$cmd" > "$in/.hpc/cmd"
  printf 'STAGE=%q\nNODE_ROOT=%q\nMIN_FREE_GB=%q\nENVNAME=%q\nTAG=%q\n' \
      "$STAGE" "$NODE_ROOT" "$MIN_FREE_GB" "$envname" "$tag" > "$in/.hpc/vars"
  # --wait 이면 sbatch 가 job 의 종료 코드를 돌려주므로 실패해도 멈추지 않고 번호만 확인한다
  jobid=$(sbatch --parsable -J "$name" -D /tmp -o "$STAGE/logs/%x-%j.out" "$@" "$HERE/hpc_job.sh" "$in") || true
  jobid=${jobid%%;*}
  [[ $jobid =~ ^[0-9]+$ ]] || { rm -rf "$in"; die "sbatch 실패 (위 메시지 확인). 파티션 이름은 sinfo -s 의 PARTITION 칸 (노드 이름이 아님, 노드 지정은 -w <노드>)"; }
  echo "$tag" > "$STAGE/jobs/$jobid"
  log "제출: job $jobid ($tag)"
  echo "$jobid"
}

# ------------------------------------------------------------------ fetch
fetch_one() {   # $1=job 번호. 아직 실행 중이면 1을 돌려준다
  local id=$1 tag src dst slog
  [[ -f $STAGE/jobs/$id ]] || die "job $id 기록 없음 ($STAGE/jobs/)"
  if squeue -h -j "$id" 2>/dev/null | grep -q .; then
    log "job $id 아직 실행 중"; return 1
  fi
  tag=$(cat "$STAGE/jobs/$id")
  src=$STAGE/out/$tag-$id
  dst=$RESULTS/$tag-$id
  mkdir -p "$dst"
  [[ -d $src ]] && rsync -a "$src/" "$dst/"
  slog=$(ls "$STAGE/logs/"*-"$id".out 2>/dev/null | head -1) || true
  [[ -n $slog ]] && cp "$slog" "$dst/slurm.log"
  rm -rf "$src" "$STAGE/in/$tag" "$STAGE/jobs/$id" ${slog:+"$slog"}
  echo "job $id → $dst  (exit $(cat "$dst/exit_code" 2>/dev/null || echo '?, 시작 전에 끝남'))"
}

cmd_fetch() {
  [[ $# -eq 1 ]] || die "사용: hpc.sh fetch <jobid|all>"
  if [[ $1 == all ]]; then
    local f
    for f in "$STAGE"/jobs/*; do
      [[ -e $f ]] && { fetch_one "${f##*/}" || true; }
    done
  else
    fetch_one "$1"
  fi
}

cmd_status() {
  squeue -u "$USER" -o '%.10i %.14j %.9T %.10M  %R' || true
  echo
  echo "가져올 결과 (hpc.sh fetch all):"
  local f n=0
  for f in "$STAGE"/jobs/*; do
    [[ -e $f ]] || continue
    echo "  ${f##*/}  $(cat "$f")"; n=$((n + 1))
  done
  [[ $n -gt 0 ]] || echo "  없음"
}

case "${1:-}" in
  env)    shift; env_build "$@" >/dev/null ;;
  submit) shift; submit "$@" >/dev/null ;;
  run)    shift; [[ $# -ge 2 ]] || die "사용: hpc.sh run <프로젝트폴더> \"<실행 명령>\" [sbatch 옵션...]"
          id=$(submit "$1" "$2" --wait "${@:3}")
          fetch_one "$id" ;;
  fetch)  shift; cmd_fetch "$@" ;;
  status) cmd_status ;;
  *)      sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac
