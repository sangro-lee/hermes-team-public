#!/usr/bin/env python3
"""Hermes 연구실 설치·점검 도우미 (표준 라이브러리만 사용).

  python3 tools/lab.py env         souls/_team_ids.md 의 ID로 모든 직원 .env 의 Discord 협업 설정을 맞춘다
  python3 tools/lab.py agy-perms   Antigravity 읽기 권한(extras/antigravity-permissions.json)을 settings.json 에 합친다
  python3 tools/lab.py reasoning   직원별 reasoning_effort 를 team.json 의 "reasoning" 값으로 맞춘다
  python3 tools/lab.py check       설치 상태를 읽기 전용으로 점검한다 (아무것도 바꾸지 않음)
  python3 tools/lab.py rename 이름  souls/_team_ids.md 의 연구자 이름을 바꾼다 (원본의 {{연구자}} 는 설치할 때 이 이름으로 채워진다)

공통 옵션: --dry-run (무엇을 바꿀지만 출력)
보안: 봇 토큰 등 비밀 값은 절대 출력하지 않는다. 수정 전 원본은 *.bak 으로 남긴다.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

TEAM_DIR = Path(__file__).resolve().parent.parent
SOULS = TEAM_DIR / "souls"
IDS_FILE = SOULS / "_team_ids.md"
TEAM_CFG = TEAM_DIR / "team.json"
HERMES = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
AGY_SETTINGS = Path.home() / ".gemini" / "antigravity-cli" / "settings.json"
AGY_PERMS = TEAM_DIR / "extras" / "antigravity-permissions.json"
SOUL_SRC = {"default": "pi", "coder": "coder", "analyst": "analyst",
            "reviewer": "reviewer", "writer": "writer", "scholar": "scholar"}
ENV_SETTINGS = {
    "DISCORD_ALLOW_BOTS": "mentions",
    "DISCORD_IGNORE_NO_MENTION": "true",
    "DISCORD_THREAD_REQUIRE_MENTION": "true",
}
DEFAULT_REASONING = {"default": "medium", "coder": "low", "analyst": "medium",
                     "reviewer": "medium", "writer": "low", "scholar": "low"}
MANAGED_BEGIN = "# >>> hermes-team managed discord block"
NAME_PLACEHOLDER = "<유저>"
NAME_RE = re.compile(r"^\s*-\s*연구자\s+([^\s:`]+):", re.M)
RENAME_TARGETS = ["souls/_team_ids.md"]   # 내 PC 전용 파일만 바꾼다. 원본(git)은 {{연구자}} 그대로 둔다

_problems = 0


def ok(msg):
    print(f"OK     {msg}")


def warn(msg):
    global _problems
    _problems += 1
    print(f"WARN   {msg}")


def info(msg):
    print(f"       {msg}")


def team():
    if not TEAM_CFG.exists():
        sys.exit(f"ERROR: {TEAM_CFG} 가 없습니다.")
    return json.loads(TEAM_CFG.read_text(encoding="utf-8"))


def profile_home(p):
    return HERMES if p == "default" else HERMES / "profiles" / p


def read_ids():
    """_team_ids.md 의 '- 이름: `<@123>`' 줄을 {이름: ID} 로 읽는다. 채워지지 않은 항목은 None."""
    ids = {}
    if not IDS_FILE.exists():
        return ids
    for line in IDS_FILE.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*-\s*(?:연구자\s+)?([^\s:`]+):\s*`<@([^>]*)>`", line)
        if m:
            val = m.group(2).strip()
            ids[m.group(1)] = val if val.isdigit() else None
    return ids


def read_env(path):
    out = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if s and not s.startswith("#") and "=" in s:
                k, v = s.split("=", 1)
                out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def write_env_keys(path, updates, dry):
    """KEY=VALUE 줄을 교체/추가한다. 다른 줄(토큰 포함)은 그대로 둔다."""
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    keep = [l for l in lines if not any(re.match(rf"^\s*{k}\s*=", l) for k in updates)]
    new = keep + [f"{k}={v}" for k, v in updates.items()]
    text = "\n".join(new).rstrip("\n") + "\n"
    if dry:
        return
    if path.exists():
        shutil.copy2(path, path.with_name(path.name + ".bak"))
    path.write_text(text, encoding="utf-8")
    os.chmod(path, 0o600)


# ------------------------------------------------------------------ env
def cmd_env(args):
    cfg = team()
    ids = read_ids()
    missing = [k for k, v in ids.items() if v is None]
    if not ids or missing:
        sys.exit(f"ERROR: {IDS_FILE} 에 채우지 않은 ID가 있습니다: {', '.join(missing) or '(항목 없음)'}")
    allowed = ",".join(ids.values())
    updates = dict(ENV_SETTINGS, DISCORD_ALLOWED_USERS=allowed)
    for p in cfg["profiles"]:
        env = profile_home(p) / ".env"
        if not env.parent.exists():
            warn(f"{p}: profile 폴더 없음 ({env.parent}) — 먼저 hermes profile create {p}")
            continue
        write_env_keys(env, updates, args.dry_run)
        print(f"{'[dry-run] ' if args.dry_run else ''}설정함  {p}: " + ", ".join(updates))
    print(f"\nDISCORD_ALLOWED_USERS = {len(ids)}명 ({', '.join(ids)})")
    print("다음: hermes gateway restart --all")


# ------------------------------------------------------------------ agy perms
def cmd_agy_perms(args):
    add = json.loads(AGY_PERMS.read_text(encoding="utf-8"))["permissions"]
    data = {}
    if AGY_SETTINGS.exists():
        data = json.loads(AGY_SETTINGS.read_text(encoding="utf-8") or "{}")
    perms = data.setdefault("permissions", {})
    added = 0
    for kind in ("allow", "deny"):
        cur = perms.setdefault(kind, [])
        for rule in add.get(kind, []):
            if rule not in cur:
                cur.append(rule)
                added += 1
    if args.dry_run:
        print(f"[dry-run] {AGY_SETTINGS}: 규칙 {added}개 추가 예정")
        return
    AGY_SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    if AGY_SETTINGS.exists():
        shutil.copy2(AGY_SETTINGS, AGY_SETTINGS.with_name("settings.json.bak"))
    AGY_SETTINGS.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{AGY_SETTINGS}: 규칙 {added}개 추가 (allow {len(perms['allow'])}, deny {len(perms['deny'])})")


# ------------------------------------------------------------------ reasoning
REASON_RE = re.compile(r'^(  reasoning_effort:\s*)"[^"]*"', re.M)


def cmd_reasoning(args):
    cfg = team()
    want = dict(DEFAULT_REASONING, **cfg.get("reasoning", {}))
    for p in cfg["profiles"]:
        path = profile_home(p) / "config.yaml"
        if not path.exists():
            warn(f"{p}: config.yaml 없음")
            continue
        text = path.read_text(encoding="utf-8")
        level = want.get(p, "medium")
        if not REASON_RE.search(text):
            warn(f"{p}: 들여쓰기 2칸의 reasoning_effort 줄을 찾지 못함 — hermes -p {p} config 로 직접 설정")
            continue
        new = REASON_RE.sub(lambda m: f'{m.group(1)}"{level}"', text, count=1)
        if new != text and not args.dry_run:
            shutil.copy2(path, path.with_name("config.yaml.bak"))
            path.write_text(new, encoding="utf-8")
        print(f"{'[dry-run] ' if args.dry_run else ''}{p}: reasoning_effort = {level}")
    print("다음: hermes gateway restart --all")


# ------------------------------------------------------------------ rename
def current_name():
    for f in (IDS_FILE, TEAM_DIR / "extras" / "_team_ids.example.md"):
        if f.exists():
            m = NAME_RE.search(f.read_text(encoding="utf-8"))
            if m:
                return m.group(1)
    return None


def cmd_rename(args):
    new = args.name.strip()
    if not re.fullmatch(r"[^\s:`<>@/\\]{1,32}", new):
        sys.exit("ERROR: 이름에는 공백과 : ` < > @ / \\ 를 쓸 수 없습니다 (예: minji, 김민지)")
    old = args.old or current_name()
    if not old:
        sys.exit("ERROR: 지금 이름을 찾지 못했습니다. --from <지금이름> 으로 알려 주세요.")
    if old == new:
        print(f"이미 '{new}' 입니다.")
        return
    files = sorted({f for pat in RENAME_TARGETS for f in TEAM_DIR.glob(pat) if f.is_file()})
    changed = 0
    for f in files:
        try:
            text = f.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        n = text.count(old)
        if n:
            changed += 1
            print(f"{'[dry-run] ' if args.dry_run else ''}{f.relative_to(TEAM_DIR)}: {n}곳")
            if not args.dry_run:
                f.write_text(text.replace(old, new), encoding="utf-8")
    print(f"\n'{old}' → '{new}' : 파일 {changed}개" + (" (dry-run, 바뀐 것 없음)" if args.dry_run else ""))
    if not args.dry_run:
        print("다음: 설치가 끝난 상태라면 bash install_souls.sh")


# ------------------------------------------------------------------ check
def run(cmd, timeout=30):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout + r.stderr).strip()
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        return -1, str(e)


def cmd_check(_args):
    print("== 1. 도구")
    for tool, why in [("hermes", "에이전트"), ("uv", "Python 환경"), ("git", "버전 관리"),
                      ("claude", "coder/writer 작성 도구"), ("agy", "scholar 문헌 읽기")]:
        path = shutil.which(tool) or (str(Path.home() / ".local/bin" / tool)
                                      if (Path.home() / ".local/bin" / tool).exists() else None)
        if path:
            rc, out = run([path, "--version"])
            ok(f"{tool:7s} {out.splitlines()[0] if out else ''}")
        else:
            warn(f"{tool:7s} 없음 ({why})")
    rc, name = run(["git", "config", "--global", "user.name"])
    rc2, mail = run(["git", "config", "--global", "user.email"])
    (ok if name and mail and rc == 0 and rc2 == 0 else warn)(f"git 사용자 {name or '(없음)'} <{mail or '없음'}>")

    print("\n== 2. 팀 설정 파일")
    cfg = team()
    for k in ("guild_id", "category_id"):
        (ok if str(cfg.get(k) or "").isdigit() else warn)(f"team.json {k} = {cfg.get(k)}")
    lob = cfg.get("lobby_channels") or []
    (ok if lob and all(str(c).isdigit() for c in lob) else warn)(f"team.json lobby_channels = {lob}")
    ids = read_ids()
    missing = [k for k, v in ids.items() if v is None]
    (ok if ids and not missing else warn)(
        f"_team_ids.md {len(ids)}명" + (f", 비어 있음: {', '.join(missing)}" if missing else ""))
    name = current_name()
    (warn if not name or name == NAME_PLACEHOLDER else ok)(
        f"연구자 이름 = {name}" + (" → python3 tools/lab.py rename <내이름>" if not name or name == NAME_PLACEHOLDER else ""))
    reg = TEAM_DIR / "projects.json"
    projects = json.loads(reg.read_text(encoding="utf-8")) if reg.exists() else []
    for pr in projects:
        (ok if Path(pr["path"]).is_dir() else warn)(f"프로젝트 {pr['name']} → {pr['path']}")

    print("\n== 3. 직원(profile)")
    token_hash = {}
    want_reason = dict(DEFAULT_REASONING, **cfg.get("reasoning", {}))
    for p in cfg["profiles"]:
        home = profile_home(p)
        if not home.exists():
            warn(f"{p}: profile 없음 ({home})")
            continue
        env = read_env(home / ".env")
        tok = env.get("DISCORD_BOT_TOKEN")
        if tok:
            token_hash.setdefault(hashlib.sha256(tok.encode()).hexdigest(), []).append(p)
        else:
            warn(f"{p}: DISCORD_BOT_TOKEN 없음 → hermes -p {p} gateway setup")
        bad = [k for k, v in ENV_SETTINGS.items() if env.get(k) != v]
        allowed = set(filter(None, env.get("DISCORD_ALLOWED_USERS", "").split(",")))
        lack = [n for n, i in ids.items() if i and i not in allowed]
        if bad or lack:
            warn(f"{p}: .env 협업 설정 불일치 {bad + ['ALLOWED_USERS에 없음:' + ','.join(lack)] if lack else bad}"
                 " → python3 tools/lab.py env")
        conf = home / "config.yaml"
        ctext = conf.read_text(encoding="utf-8") if conf.exists() else ""
        m = REASON_RE.search(ctext)
        cur = m.group(0).split('"')[1] if m else "?"
        msec = re.search(r"^model:\s*\n((?:[ \t#].*\n|\s*\n)*)", ctext, re.M)
        model = re.search(r'^\s+default:\s*"?([^"\n]+)"?', msec.group(1), re.M) if msec else None
        soul = home / "SOUL.md"
        src = SOULS / f"{SOUL_SRC.get(p, p)}.md"
        # install_souls.sh 와 같은 결과: 원본 + _team_ids.md, {{연구자}} → 이름
        expected = ((src.read_text(encoding="utf-8") + IDS_FILE.read_text(encoding="utf-8")).replace("{{연구자}}", name or "")
                    if src.exists() and IDS_FILE.exists() else None)
        soul_ok = soul.exists() and expected is not None and soul.read_text(encoding="utf-8") == expected
        managed = MANAGED_BEGIN in ctext
        line = (f"{p:9s} 모델={model.group(1).strip() if model else '?'}  reasoning={cur}"
                f"{'' if cur == want_reason.get(p) else ' (권장 ' + want_reason.get(p, '?') + ')'}"
                f"  SOUL={'최신' if soul_ok else '다름'}  채널연결={'있음' if managed else '없음'}")
        (ok if soul_ok and managed and cur == want_reason.get(p) else warn)(line)
        if not soul_ok:
            info("SOUL 이 souls/ 원본과 다름 → bash install_souls.sh")
        if not managed:
            info("채널 연결 블록 없음 → python3 newproject.py sync")
    dup = [ps for ps in token_hash.values() if len(ps) > 1]
    if dup:
        warn(f"같은 봇 토큰을 쓰는 profile: {dup} → 각자 자기 봇 토큰으로 gateway setup 다시")
    elif token_hash:
        ok(f"봇 토큰 {len(token_hash)}개 모두 서로 다름")

    print("\n== 4. 게이트웨이·예약 작업")
    rc, out = run(["hermes", "gateway", "status"])
    lines = out.splitlines()
    shown = next((l.strip() for l in lines if "running" in l.lower()), lines[0] if lines else "응답 없음")
    (ok if rc == 0 and "running" in out.lower() else warn)("게이트웨이: " + shown)
    rc, out = run(["hermes", "cron", "list"])
    (ok if "morning-brief" in out else warn)("아침 브리핑(morning-brief) " + ("등록됨" if "morning-brief" in out else "없음"))

    print("\n== 5. Antigravity 권한")
    if AGY_SETTINGS.exists():
        try:
            perms = json.loads(AGY_SETTINGS.read_text(encoding="utf-8")).get("permissions", {})
        except json.JSONDecodeError:
            perms = {}
            warn(f"{AGY_SETTINGS} JSON 오류")
        n = sum(1 for r in perms.get("allow", []) if r.startswith("read_url("))
        (ok if n >= 10 else warn)(f"read_url 허용 {n}개" + ("" if n >= 10 else " → python3 tools/lab.py agy-perms"))
    else:
        warn(f"{AGY_SETTINGS} 없음 → agy 로그인 후 python3 tools/lab.py agy-perms")

    print("\n" + ("READY — 모든 점검 통과" if _problems == 0 else f"점검 필요 {_problems}건 (위 WARN 참고)"))
    return 0 if _problems == 0 else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("env", "agy-perms", "reasoning", "check"):
        s = sub.add_parser(name)
        s.add_argument("--dry-run", action="store_true")
    s = sub.add_parser("rename")
    s.add_argument("name", help="새 연구자 이름 (Discord에서 불릴 이름, 공백 없이)")
    s.add_argument("--from", dest="old", help="지금 이름 (생략하면 souls/_team_ids.md 에서 찾음)")
    s.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    fn = {"env": cmd_env, "agy-perms": cmd_agy_perms, "reasoning": cmd_reasoning, "check": cmd_check,
          "rename": cmd_rename}[a.cmd]
    sys.exit(fn(a) or 0)


if __name__ == "__main__":
    main()
