#!/usr/bin/env python3
"""SOUL 파일에 '읽기·출력 절약' 규칙만 추가한다. 다른 내용은 건드리지 않는다.

이미 이 규칙이 있는 파일은 건너뛴다 (여러 번 실행해도 안전).
넣는 위치: '## 장기 기억' 절 바로 앞 → 없으면 '## Discord' 앞 → 둘 다 없으면 파일 끝.

사용: python3 tools/add_reading_rule.py            (souls/ 폴더의 모든 역할 파일)
      python3 tools/add_reading_rule.py --dry-run  (무엇을 바꿀지만 출력)
그다음: bash install_souls.sh
"""
import shutil
import sys
from pathlib import Path

HEADING = "## 읽기·출력 절약 (토큰)"
RULE = HEADING + '''
**항상 전체를 읽는다:** `AGENTS.md`, `research/RESEARCH_STATE.md`, `HYPOTHESES.md`, 실험 명세(`experiments/*.yaml`), 카드 본문, 검토·수정 대상 코드와 diff.
**잘라서 읽는다:**
- 명령 결과(설치·테스트·빌드): 끝부분(`| tail -n 50`)과 오류 줄(`| grep -i -E "error|fail|warn"`)만
- 로그 파일: 끝부분과 오류 줄만
- 데이터 파일(csv, 큰 json): 앞 몇 줄(`head`)과 크기·요약 통계만. 전체를 출력하지 않는다
**공통:** 잘라 읽은 것으로 판단하기 부족하면 **더 읽는다** (아끼느라 틀리지 않는다). 같은 대화에서 이미 읽었고 바뀌지 않은 파일은 다시 읽지 않는다.

'''

dry = "--dry-run" in sys.argv
souls = Path(__file__).resolve().parent.parent / "souls"
for f in sorted(souls.glob("*.md")):
    if f.name.startswith("_"):
        continue
    text = f.read_text(encoding="utf-8")
    if HEADING in text:
        print(f"건너뜀 (이미 있음): {f.name}")
        continue
    for anchor in ("## 장기 기억", "## Discord"):
        i = text.find("\n" + anchor)
        if i != -1:
            new = text[: i + 1] + RULE + text[i + 1 :]
            where = f"'{anchor}' 앞"
            break
    else:
        new = text.rstrip("\n") + "\n\n" + RULE
        where = "파일 끝"
    if dry:
        print(f"[dry-run] 추가 예정: {f.name} ({where})")
        continue
    shutil.copy2(f, f.with_name(f.name + ".bak"))
    f.write_text(new, encoding="utf-8")
    print(f"추가함: {f.name} ({where})")
if not dry:
    print("\n다음: bash install_souls.sh  → 대화 중이던 채널에서 봇에게 /reset")
