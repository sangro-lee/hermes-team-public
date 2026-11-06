"""lab-handoff: PI 대화를 인계 노트와 함께 새로 시작한다.

- 시스템 프롬프트 섹션: default 프로필의 새 대화마다 state/pi-handoff.md를 넣는다
  (Hermes가 새 대화를 만들 때 한 번만 읽는다. 압축돼도 남는다).
- pre_gateway_dispatch: state/pi-reset-requested에 적힌 session_id가 지금 이 채널의 대화이면,
  다음 사용자 메시지에서 gateway의 /new 경로(_handle_reset_command)로 새 대화를 만든다.
  요청 파일은 extras/pi-handoff.sh가 인계 노트를 다 쓴 뒤에만 만든다.
- pre_llm_call: PI의 매 턴 사용자 메시지 끝에 souls/pi-rules.md(핵심 규칙 몇 줄)를 붙인다.
  긴 대화에서 앞쪽 SOUL보다 최근 맥락을 따르는 작은 모델용 리마인더다. 파일을 고치면 다음 턴부터 반영된다.
- /brief [프로젝트]: 아침 브리핑(morning-brief.sh, Claude 정리)을 지금 돌려 보낸 채널에 올린다. PI 모델을 거치지 않는다.
  프로젝트 채널에서는 그 프로젝트만, 로비(#hermes)에서는 전체. 인자로 프로젝트 이름을 줄 수도 있다.
- post_tool_call: 터미널 `hermes kanban create`는 완료 알림 구독을 안 붙이므로(kanban_create 도구만 붙인다),
  출력의 "Created t_..."를 읽어 그 대화 채널로 같은 구독을 붙인다. 안 붙이면 카드가 끝나도 PI가 모른다.
리셋 방식은 hermes-session-reset-policy 0.3.0 플러그인을 따랐다.
"""
from __future__ import annotations

import dataclasses
import json
import inspect
import logging
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

logger = logging.getLogger("hermes.plugins.lab_handoff")

STATE = Path.home() / "Projects" / "hermes-team" / "state"
HANDOFF = STATE / "pi-handoff.md"
RESET_FLAG = STATE / "pi-reset-requested"
RULES = Path.home() / "Projects" / "hermes-team" / "souls" / "pi-rules.md"
PROJECTS = Path.home() / "Projects" / "hermes-team" / "projects.json"
TEAM_IDS = RULES.with_name("_team_ids.md")
TEAM = PROJECTS.with_name("team.json")
NAME_RE = re.compile(r"^\s*-\s*연구자\s+([^\s:`]+):", re.M)
RESEARCHER_ID_RE = re.compile(r"^\s*-\s*연구자\s+[^\s:`]+:\s*`?<@(\d+)>", re.M)
RULES_MAX_CHARS = 1500
PROFILE = "default"
MAX_CHARS = 4000


def _handoff_section(info: Any) -> str:
    if (info.get("profile_name") or PROFILE) != PROFILE:
        return ""
    try:
        text = HANDOFF.read_text(encoding="utf-8").strip()
        written = datetime.fromtimestamp(HANDOFF.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
    except OSError:
        return ""
    if not text:
        return ""
    head = (f"## 이전 대화 인계 노트 (Claude 자동 작성, {written})\n"
            "이전 PI 대화에서 이어지는 지시와 상태다. 칸반·git·RESEARCH_STATE와 다르면 그쪽이 맞다.\n\n")
    return (head + text)[: MAX_CHARS - 200]


def _is_slash_command(event: Any) -> bool:
    get_command = getattr(event, "get_command", None)
    if callable(get_command):
        try:
            return bool(get_command())
        except Exception:
            pass
    text = getattr(event, "text", None)
    return isinstance(text, str) and text.lstrip().startswith("/")


async def _maybe_reset(event: Any, gateway: Any, session_store: Any, **_extra: Any):
    try:
        wanted = RESET_FLAG.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    source = getattr(event, "source", None)
    if not wanted or source is None or session_store is None:
        return None
    if (getattr(source, "profile", None) or PROFILE) != PROFILE or _is_slash_command(event):
        return None
    try:
        key = gateway._session_key_for_source(source)
        entry = session_store.lookup_by_session_key(key) if key else None
    except Exception:
        logger.debug("lab-handoff: session lookup failed", exc_info=True)
        return None
    if entry is None or getattr(entry, "session_id", None) != wanted:
        return None  # 다른 채널의 대화이거나 이미 새 대화
    if getattr(entry, "active_turn_token", None):
        return None  # 실행 중인 턴이 있으면 다음 메시지로 미룬다
    funnel = getattr(gateway, "_handle_reset_command", None)
    if not callable(funnel):
        logger.warning("lab-handoff: gateway reset funnel not found; not resetting")
        return None
    try:
        outcome = funnel(dataclasses.replace(event, text=""))
        if inspect.isawaitable(outcome):
            await outcome
    except Exception:
        logger.warning("lab-handoff: reset of %s failed", key, exc_info=True)
        return None
    RESET_FLAG.unlink(missing_ok=True)
    logger.info("lab-handoff: started a new PI session for %s (old %s)", key, wanted)
    return None  # 원래 메시지는 새 대화로 그대로 전달된다


def _rules_reminder(**_kwargs: Any):
    try:
        from hermes_cli.profiles import get_active_profile_name
        if get_active_profile_name() != PROFILE:
            return None
        text = RULES.read_text(encoding="utf-8").strip()
        m = NAME_RE.search(TEAM_IDS.read_text(encoding="utf-8"))
    except Exception:
        return None
    text = text.replace("{{연구자}}", m.group(1) if m else "연구자")
    return text[:RULES_MAX_CHARS] or None


def _project_for(raw_args: str, chat_id: str) -> str | None:
    """/brief 인자(프로젝트 이름) 또는 이 채널에 연결된 프로젝트 (projects.json). 로비면 None = 전체."""
    try:
        projects = json.loads(PROJECTS.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        projects = []
    names = {p.get("name") for p in projects}
    arg = (raw_args or "").strip().split()[0] if (raw_args or "").strip() else ""
    if arg:
        return arg if arg in names else ""
    return next((p["name"] for p in projects if str(p.get("channel_id")) == str(chat_id)), None)


def _brief_command(raw_args: str = "", source: Any = None, **_kwargs: Any) -> str:
    chat_id = str(getattr(source, "chat_id", "") or "")
    project = _project_for(raw_args, chat_id)
    if project == "":
        return f"'{raw_args.strip()}' 프로젝트를 찾지 못했습니다. 목록: python3 ~/Projects/hermes-team/newproject.py list"
    script = Path.home() / ".hermes" / "scripts" / "morning-brief.sh"
    hermes = shutil.which("hermes") or str(Path.home() / ".local" / "bin" / "hermes")
    target = f"discord:{chat_id}" if chat_id else "discord"
    cmd = f'bash "{script}" {project or ""} | "{hermes}" send -t "{target}" -f - -q'
    try:
        subprocess.Popen(["bash", "-c", cmd], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError as exc:
        return f"브리핑을 시작하지 못했습니다: {exc}"
    what = f"{project} 프로젝트" if project else "전체 프로젝트"
    return f"{what} 브리핑을 시작했습니다. Claude가 정리해서 1~3분 뒤 이 채널에 올립니다."


CREATED_RE = re.compile(r"\bCreated (t_[0-9a-f]+)")
CREATED_JSON_RE = re.compile(r"\"id\":\s*\"(t_[0-9a-f]+)\"")  # create --json 출력
# 셸 `--board qenc-mol`, `--board=qenc-mol`와 파이썬 리스트 `"--board", "qenc-mol"` 모두
BOARD_RE = re.compile(r"--board(?:[ =]|['\"],\s*)['\"]?([\w.-]+)")
CREATE_TOOLS = {"terminal": "command", "execute_code": "code"}  # 도구 이름 → 명령이 담긴 인자


SUB_FIELDS = ("platform", "chat_id", "thread_id", "user_id", "user_id_alt", "chat_type",
              "notifier_profile", "delivery_mode", "delivery_metadata")


def _channel_sub_template(subs: list[dict], board: str | None) -> dict | None:
    """도구 호출 밖이라 대화 채널을 못 읽을 때: 이 보드 프로젝트 채널(projects.json)로 걸린 최근 구독을 본뜨고,
    없으면 team.json(guild_id)과 _team_ids.md(연구자 ID)로 만든다."""
    try:
        projects = json.loads(PROJECTS.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    channel = next((str(p.get("channel_id")) for p in projects if p.get("name") == board), None)
    if not channel:
        return None
    same = [s for s in subs if s.get("platform") == "discord" and str(s.get("chat_id")) == channel]
    if same:
        latest = max(same, key=lambda s: s.get("created_at") or 0)
        return {k: latest.get(k) or None for k in SUB_FIELDS}
    # 새 프로젝트라 본뜰 구독이 없으면 kanban_create 도구가 만드는 것과 같은 모양으로 만든다
    try:
        guild = str(json.loads(TEAM.read_text(encoding="utf-8")).get("guild_id") or "")
        m = RESEARCHER_ID_RE.search(TEAM_IDS.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    meta = {"chat_type": "group", **({"scope_id": guild} if guild else {})}
    return dict(platform="discord", chat_id=channel, thread_id=None, user_id=m.group(1) if m else None,
                user_id_alt=None, chat_type="group", notifier_profile=PROFILE,
                delivery_mode="notify+wake", delivery_metadata=meta)


def _subscribe_created(tool_name: str = "", args: Any = None, result: Any = None, **_kwargs: Any):
    """터미널 `hermes kanban create`로 만든 카드에도 kanban_create 도구와 같은 완료 알림 구독을 붙인다.
    execute_code 안에서 subprocess로 부른 것도 같다(t_6703d934가 이 경로로 빠졌다).
    구독은 이 대화의 채널로 간다(도구와 같은 _resolve_notify_target). 게이트웨이 대화가 아니면(작업자·CLI) 건너뛴다."""
    if tool_name not in CREATE_TOOLS or not isinstance(args, dict):
        return None
    command = str(args.get(CREATE_TOOLS[tool_name]) or "")
    if "kanban" not in command or "create" not in command:
        return None
    if isinstance(result, str):
        try:
            result = json.loads(result)
        except ValueError:
            pass
    output = result.get("output", "") if isinstance(result, dict) else str(result or "")
    task_ids = CREATED_RE.findall(output) or CREATED_JSON_RE.findall(output)
    if not task_ids:
        return None
    m = BOARD_RE.search(command)
    board = m.group(1) if m else None
    logger.info("lab-handoff: terminal created %s on board %s (via %s)", task_ids, board, tool_name)
    try:
        from tools.kanban_tools import _board, _resolve_notify_target
        from hermes_cli import kanban_db_notify as kbn
        target = _resolve_notify_target()
        if target is not None and target["platform"] == "tui":
            return None
        with _board(board) as (_kb, conn):
            if target is None:
                target = _channel_sub_template(kbn.list_notify_subs(conn), board)
            if target is None:
                logger.warning("lab-handoff: no channel to subscribe for %s (board %s)", task_ids, board)
                return None
            for tid in task_ids:
                if any(s["platform"] == target["platform"] and s["chat_id"] == target["chat_id"]
                       for s in kbn.list_notify_subs(conn, tid)):
                    continue
                kbn.add_notify_sub(conn, task_id=tid, **target)
                logger.info("lab-handoff: subscribed %s:%s to %s", target["platform"], target["chat_id"], tid)
    except Exception:
        logger.warning("lab-handoff: auto-subscribe for %s failed", task_ids, exc_info=True)
    return None


def register(ctx: Any) -> None:
    ctx.register_system_prompt_section("lab-handoff.pi", _handoff_section, max_chars=MAX_CHARS)
    ctx.register_hook("pre_gateway_dispatch", _maybe_reset)
    ctx.register_hook("pre_llm_call", _rules_reminder)
    ctx.register_hook("post_tool_call", _subscribe_created)
    ctx.register_command("brief", _brief_command, "오늘 할 일 브리핑 — 프로젝트 채널은 그 프로젝트만, 로비는 전체 (Claude 정리)",
                         args_hint="[프로젝트]")
