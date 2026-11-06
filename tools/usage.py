#!/usr/bin/env python3
"""Hermes 로그에서 시간대별·직원별 모델 사용량을 합산한다 (읽기 전용).

  python3 tools/usage.py                 오늘, 시간대별 (직원 합계)
  python3 tools/usage.py --by-profile    오늘, 시간대 × 직원
  python3 tools/usage.py --date 2026-10-28
  python3 tools/usage.py --since "2026-10-27 20:00"

열 설명:
  호출   = 모델 API 호출 횟수
  입력   = 호출마다 보낸 입력 토큰 합 (캐시로 다시 읽은 몫 포함)
  새입력 = 입력 중 캐시가 아닌 몫 (새로 읽은 양)
  출력   = 모델이 쓴 토큰
로그 줄 형식: "... API call #N: model=M provider=P in=I out=O total=T ... cache=C/I ..."
"""
import argparse
import datetime as dt
import glob
import os
import re
from collections import defaultdict
from pathlib import Path

HERMES = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
LINE = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}):\d{2}:\d{2}.*?API call #\d+: model=(\S+).*? in=(\d+) out=(\d+)(?:.*? cache=(\d+)/\d+)?")


def log_files():
    """(직원 이름, 파일) 목록. PI(default)는 ~/.hermes/logs, 직원은 profiles/<이름>/logs."""
    out = [("PI", f) for f in glob.glob(str(HERMES / "logs" / "agent.log*"))]
    for d in sorted(glob.glob(str(HERMES / "profiles" / "*"))):
        name = Path(d).name
        out += [(name, f) for f in glob.glob(str(Path(d) / "logs" / "agent.log*"))]
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--date", help="YYYY-MM-DD (기본: 오늘)")
    ap.add_argument("--since", help="'YYYY-MM-DD HH:MM' 이후 전부 (--date 대신)")
    ap.add_argument("--by-profile", action="store_true", help="시간대 × 직원으로 나눠 보기")
    a = ap.parse_args()
    day = a.date or dt.date.today().isoformat()
    since = a.since[:13] if a.since else None

    rows = defaultdict(lambda: [0, 0, 0, 0])           # key -> calls, in, new_in, out
    models = defaultdict(lambda: defaultdict(int))      # profile -> model -> calls
    seen = set()
    for prof, f in log_files():
        try:
            fh = open(f, encoding="utf-8", errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
                m = LINE.search(line)
                if not m:
                    continue
                hour, model, i, o, c = m.group(1), m.group(2), int(m.group(3)), int(m.group(4)), int(m.group(5) or 0)
                if since:
                    if hour < since:
                        continue
                elif not hour.startswith(day):
                    continue
                sig = (prof, line[:23], i, o)            # 회전된 로그가 겹칠 때 중복 제거
                if sig in seen:
                    continue
                seen.add(sig)
                key = (hour, prof) if a.by_profile else (hour,)
                r = rows[key]
                r[0] += 1; r[1] += i; r[2] += max(i - c, 0); r[3] += o
                models[prof][model] += 1

    if not rows:
        print("해당 기간에 API 호출 기록이 없습니다. (로그 위치:", HERMES, ")")
        return
    head = f"{'시간':13s} " + (f"{'직원':9s} " if a.by_profile else "") + f"{'호출':>6s} {'입력':>12s} {'새입력':>10s} {'출력':>9s}"
    print(head); print("-" * len(head.encode("utf-8")))
    tot = [0, 0, 0, 0]
    for key in sorted(rows):
        r = rows[key]
        tot = [x + y for x, y in zip(tot, r)]
        print(f"{key[0]}시 " + (f"{key[1]:9s} " if a.by_profile else "") + f"{r[0]:6d} {r[1]:12,d} {r[2]:10,d} {r[3]:9,d}")
    print("-" * len(head.encode("utf-8")))
    print(f"{'합계':13s} " + (" " * 10 if a.by_profile else "") + f"{tot[0]:6d} {tot[1]:12,d} {tot[2]:10,d} {tot[3]:9,d}")
    print("\n직원별 모델 (호출 수):")
    for prof in sorted(models):
        print(f"  {prof:9s} " + ", ".join(f"{m} {n}" for m, n in sorted(models[prof].items(), key=lambda x: -x[1])))


if __name__ == "__main__":
    main()
