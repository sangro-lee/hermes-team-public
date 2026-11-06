#!/usr/bin/env bash
# hpc.sh submit 이 보내는 job 본체. 계산노드에서 돈다 (직접 sbatch 하지 않는다).
#   /home 의 코드를 로컬(/var/tmp/$USER/job/<번호>)로 복사 → 환경은 이 노드에 없을 때만 한 번 풀기
#   → 실행 → out/ 만 /home 으로 돌려놓고 로컬 작업 폴더를 지운다 (실패해도)
set -uo pipefail
IN=$1
source "$IN/.hpc/vars"
W=$NODE_ROOT/job/$SLURM_JOB_ID
OUT=$STAGE/out/$TAG-$SLURM_JOB_ID
ENVDIR=$NODE_ROOT/env/$ENVNAME
echo "[hpc] $(hostname) job $SLURM_JOB_ID 시작 $(date '+%F %T')"

finish() {
  local rc=$?
  mkdir -p "$OUT"
  [[ -d $W/out ]] && cp -r "$W/out/." "$OUT/"
  echo "$rc" > "$OUT/exit_code"
  rm -rf "$W" "$IN"
  echo "[hpc] 끝 $(date '+%F %T') exit=$rc"
}
trap finish EXIT
set -e

mkdir -p "$NODE_ROOT/env" "$NODE_ROOT/job"
free=$(df -Pk "$NODE_ROOT" | awk 'NR==2 {print int($4 / 1048576)}')
if (( free < MIN_FREE_GB )); then
  echo "[hpc] $NODE_ROOT 남은 공간 ${free}G < ${MIN_FREE_GB}G — 시작하지 않음" >&2
  exit 90
fi

# 같은 노드에 동시에 들어온 job 이 같은 환경을 두 번 풀지 않게 잠근다
(
  flock 9
  if [[ ! -f $ENVDIR/.ok ]]; then
    echo "[hpc] 환경 풀기: $ENVDIR"
    rm -rf "$ENVDIR"
    tar -xzf "$STAGE/envs/$ENVNAME.tar.gz" -C /
    touch "$ENVDIR/.ok"
  fi
) 9>"$NODE_ROOT/env/.$ENVNAME.lock"
touch "$ENVDIR/.ok"   # 마지막으로 쓴 시각 (오래된 환경 정리용)

mkdir -p "$W"
cp -R "$IN/." "$W/"   # -a 는 NFS 의 ACL 을 로컬 디스크에 옮기려다 실패한다 (Operation not supported)
cd "$W"
mkdir -p out
export VIRTUAL_ENV=$ENVDIR/venv
export PATH=$ENVDIR/venv/bin:$PATH
export PYTHONPATH=$W/src:$W${PYTHONPATH:+:$PYTHONPATH}

echo "[hpc] 실행: $(cat .hpc/cmd)"
set +e
bash -c "$(cat .hpc/cmd)" > out/run.log 2>&1
exit $?
