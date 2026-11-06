"""PI(default 프로필) 대화 압축 → 인계 노트 갱신 스크립트를 백그라운드로 띄운다.

~/.hermes/hooks/ 는 default 프로필 전용이라 다른 직원 대화에는 걸리지 않는다.
"""
import subprocess
from pathlib import Path

SCRIPT = Path.home() / ".hermes" / "scripts" / "pi-handoff.sh"


async def handle(event_type: str, context: dict):
    sid = context.get("session_id")
    if not sid or not SCRIPT.exists():
        return
    subprocess.Popen(
        ["bash", str(SCRIPT), str(sid), str(context.get("compression_count") or 0)],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
