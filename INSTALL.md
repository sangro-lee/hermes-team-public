# Hermes AI 연구실 — 새 컴퓨터 설치 매뉴얼

이 문서만 보고 **처음 보는 사람도** 다른 Linux 컴퓨터에 지금과 똑같은 연구실을 만들 수 있게 썼다.
SOUL, 템플릿, 스크립트는 이 폴더(`hermes-team/`)에 있는 것을 그대로 쓴다.
구조와 각 직원이 어떻게 움직이는지는 `docs/Hermes_Lab_Overview.pptx`에 정리돼 있다.

> 걸리는 시간: 처음이면 2~3시간. 대부분은 Discord 봇 6개를 만드는 시간이다.
> 표기: `<이름>`은 실제 값으로 바꿔 넣는 자리다. 명령은 모두 일반 사용자로 실행하고, `sudo`는 쓰라고 한 곳에서만 쓴다.

---

## 0. 시작 전에

### 0-1. 어떤 경우인지 고르기

| 경우 | 할 일 |
|---|---|
| **A. 새 연구실을 하나 더 만든다** (다른 PC, 다른 사람, HPC 등) | 이 문서를 처음부터 끝까지 따라 한다. **봇 6개를 새로 만든다.** |
| **B. 지금 연구실을 이 PC에서 다른 PC로 옮긴다** | [부록 A](#부록-a-지금-연구실을-다른-pc로-옮기기)만 따라 한다. |

> **같은 봇 토큰을 두 컴퓨터에서 동시에 쓰면 안 된다.** 나중에 켠 쪽이 연결에 실패한다. 두 곳에서 동시에 돌리려면 봇을 따로 만든다.

### 0-2. 필요한 계정

| 계정 | 쓰는 곳 | 비고 |
|---|---|---|
| **ChatGPT 구독** (Plus/Pro) | analyst·reviewer의 두뇌, 대화 압축 요약 (Hermes 모델) | Hermes에서 "ChatGPT or Codex Subscription"으로 로그인 |
| **로컬 모델** (GPU) | PI·coder·writer·scholar의 두뇌 (Qwen3.6-35B-A3B, llama.cpp) | 설치는 [`LOCAL_MODEL.md`](LOCAL_MODEL.md) (개인 데스크탑 / 공용 서버). 직원을 만든 뒤(3장) 연결한다 |
| **Claude 구독** (Pro/Max) | coder·writer의 작성 도구 **Claude Code** (`claude -p`) | **Hermes 모델로 연결하지 않는다** (약관). 명령줄 도구로만 쓴다 |
| **Google 계정** | scholar의 논문 읽기 도구 **Antigravity CLI** (`agy -p`) | |
| **Discord 계정 + 개인 서버** | 직원들과 대화하는 곳 | 서버 관리자여야 함 |
| GitHub (선택) | 예비 모델(Copilot), 원격 백업 | 지금은 예비 모델 없이 운영 중 |

### 0-3. 컴퓨터

- Linux (Ubuntu 22.04 이상 권장), 인터넷, 사용자 계정 하나
- `git`, `curl`, `python3`이 있어야 한다:
  ```bash
  sudo apt update && sudo apt install -y git curl python3
  ```

### 0-4. 검증된 버전 (2026-10-27, 원래 PC에서 `lab.py check` READY)

| 도구 | 버전 |
|---|---|
| Hermes Agent | v0.22.5 (2026.9.24, stable) |
| Claude Code | 2.1.311 |
| Antigravity CLI (`agy`) | 1.4.7 |
| uv | 0.13.5 |
| git | 2.55.0 |

더 새 버전이어도 대개 동작한다. 명령이 바뀐 것 같으면 `<도구> --help`로 확인한다.

### 0-5. ID 기록표 (설치하면서 채운다)

메모장에 아래 표를 복사해 두고 채워 나간다. **토큰은 비밀이다.** 채팅이나 git에 올리지 않는다.

```text
[Discord]
서버(guild) ID        :
로비 채널(#hermes) ID  :
Projects 카테고리 ID   :
내 사용자 ID           :

[봇]          Application ID       봇(사용자) ID         토큰(비밀)
PI(hermes-researcher):
coder               :
analyst             :
reviewer            :
writer              :
scholar             :
```

---

## 1. 기본 도구 설치

### 1-1. git 기본값
```bash
git config --global user.name  "<이름>"
git config --global user.email "<이메일>"
git config --global init.defaultBranch main
```
에이전트가 만드는 commit에 이 이름이 남는다. 마지막 줄을 넣어 두면 새 저장소의 기본 브랜치가 `master`가 아니라 `main`이 된다.

### 1-2. uv (프로젝트별 Python 환경)
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
uv --version
```

### 1-3. Hermes Agent
```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
hermes --version
```
- 코드는 `~/.hermes/hermes-agent/`, 명령은 `~/.local/bin/hermes`, 데이터는 `~/.hermes/`에 들어간다.
- `hermes: command not found`가 나오면 `source ~/.bashrc`를 한 번 더 하거나, 터미널을 새로 연다.

### 1-4. Claude Code
```bash
curl -fsSL https://claude.ai/install.sh | bash
claude            # 처음 한 번: Claude 구독 계정으로 로그인 → /exit
claude -p "OK라고만 답해" --max-turns 1
```
- 대화형으로 열면 "이 폴더를 신뢰하겠냐"고 묻는다. 홈 폴더(`~`)에서 열었다면 **No**를 고르고, 프로젝트 폴더에서 열었을 때만 Yes를 고른다. 에이전트가 쓰는 `claude -p` 모드는 이 질문 없이 동작한다.
- 마지막 줄에서 `OK`가 나오면 끝이다.

### 1-5. Antigravity CLI
1. Google Antigravity 공식 안내에 있는 **CLI 설치 방법**대로 `agy`를 설치한다.
2. `agy`를 한 번 실행해 Google 계정으로 로그인한다.
3. 동작을 확인한다:
   ```bash
   agy --version
   agy -p "Reply with OK" --output-format json --print-timeout 2m
   ```
   출력 JSON의 `"status"`가 `"SUCCESS"`면 된다. 권한 설정은 4-5단계에서 한다.

### 1-6. 이 폴더 가져오기
GitHub 저장소를 **`~/Projects/hermes-team`**으로 받는다. 나중에 `git pull`로 규칙·스크립트 업데이트를 받는다.
```bash
mkdir -p ~/Projects && cd ~/Projects
git clone https://github.com/<저장소>.git hermes-team
ls ~/Projects/hermes-team        # INSTALL.md, set_name.sh, souls/, template/, tools/, extras/ 가 보여야 함
```
저장소에는 원래 연구실의 Discord ID·프로젝트 목록·기억이 들어 있지 않다. 내 것은 내 PC에만 만든다 (git에 올라가지 않음).

**연구자 이름 정하기:** 원본 SOUL·템플릿에는 연구자 이름이 `{{연구자}}`로 적혀 있고, 설치할 때 내 이름으로 채워진다. 직원들은 이 이름으로 나를 부르고 승인을 요청한다.
```bash
cd ~/Projects/hermes-team
bash set_name.sh <내이름>        # 예: minji 또는 김민지 (공백 없이). 나중에 다시 실행해도 된다
```
`set_name.sh`는 내 PC 전용 파일(`team.json`, `souls/_team_ids.md`, `projects.json`)이 없으면 예시에서 만들고, commit 전 개인 정보 검사(`tools/git-hooks/pre-commit`)를 켠다.

**업데이트 받기:** `cd ~/Projects/hermes-team && git pull && bash extras/install_extras.sh && bash install_souls.sh`

---

## 2. Discord 서버 준비

### 2-1. 개발자 모드 켜기 (ID 복사용)
Discord → 사용자 설정(톱니바퀴) → **고급** → **개발자 모드** 켜기.
이제 서버, 채널, 사용자를 우클릭하면 **ID 복사**가 나온다.

### 2-2. 서버 구성 만들기
| 만들 것 | 이름 (권장) | 용도 |
|---|---|---|
| 텍스트 채널 | `#hermes` | **로비.** 전체 상황, 새 프로젝트 요청. PI가 멘션 없이 답한다 |
| 카테고리 | `Projects` | PI가 프로젝트 채널을 **자동으로** 이 안에 만든다 |
| 텍스트 채널 (선택) | `#sandbox` | 시험용 |

서버 이름 우클릭 → ID 복사 (서버 ID), `#hermes` 우클릭 → ID 복사 (로비 ID), `Projects` 우클릭 → ID 복사 (카테고리 ID), 내 프로필 우클릭 → ID 복사 (내 사용자 ID). 모두 0-5 기록표에 적는다.

---

## 3. 직원 6명 만들기

| 직원 | Discord 봇 이름 | Hermes profile |
|---|---|---|
| PI | `hermes-researcher` | `default` (기본 profile) |
| coder | `coder` | `coder` |
| analyst | `analyst` | `analyst` |
| reviewer | `reviewer` | `reviewer` |
| writer | `writer` | `writer` |
| scholar | `scholar` | `scholar` |

### 3-1. Discord 봇 6개 만들기 (봇마다 반복)
1. https://discord.com/developers/applications → **New Application** → 이름 입력(위 표) → Create
2. **General Information** → **Application ID** 복사 → 기록표
3. 왼쪽 **Bot**
   - **Reset Token** → 토큰 복사 → 기록표 (다시 볼 수 없다)
   - **Message Content Intent** 켜기 (**필수.** 꺼져 있으면 봇이 접속하지 못한다) → **Save Changes**
4. 서버에 초대: 브라우저 주소창에 아래를 입력한다 (`APP_ID` 자리에 2번 값)
   ```text
   https://discord.com/oauth2/authorize?scope=bot+applications.commands&permissions=274878024768&client_id=APP_ID
   ```
   - 승인 화면 위쪽의 봇 이름이 **지금 만드는 봇인지** 확인 → 내 서버 선택 → 승인
5. 서버 멤버 목록에서 그 봇 우클릭 → **ID 복사** (봇 ID) → 기록표

### 3-2. PI(default) 설정
```bash
hermes model                 # "ChatGPT or Codex Subscription" 선택 → 화면의 코드로 로그인 → 모델 gpt-6.1-sol
hermes gateway setup         # Discord 선택 → PI(hermes-researcher) 토큰 → "Allow yourself?" y → Home channel 은 Enter
hermes chat -q "OK라고만 답해"
```
> `hermes setup`이 **Nous Portal** 로그인을 권하면 Ctrl+C로 나오고 위처럼 `hermes model`로 고른다 (Nous Portal은 별도 유료 서비스).

### 3-3. 직원 5명 profile 만들기
PI 설정(모델 로그인)을 복제해서 만든다:
```bash
hermes profile create coder --clone \
  --description "코드 구현·수정 담당. 실제 코드 작성은 Claude Code(claude -p)에 맡기고, 결과를 테스트로 검증해 보고한다. 연구 기록과 실험 명세는 수정하지 않는다."
hermes profile create analyst --clone \
  --description "실험 실행과 결과 분석 담당. 승인된 실험 명세만 실행하고, success_criteria 판정과 FINDINGS 수정안을 만든다. 코드는 수정하지 않는다."
hermes profile create reviewer --clone \
  --description "독립 검토 담당. 코드·분석 결과·논문 초안·문헌 조사를 검토하고, GPT가 만든 판정은 Claude 읽기 전용 2차 의견을 받는다. 직접 수정하지 않는다."
hermes profile create writer --clone \
  --description "논문·보고서 초안 담당. 작성은 Claude Code에 docs/paper/ 쓰기만 허용해 맡기고, 수치는 results와, 인용은 references.bib와 대조해 검증한다."
hermes profile create scholar --clone \
  --description "문헌 조사 담당. 관련 논문을 찾아 Antigravity로 읽고 근거 위치와 함께 정리하며, arXiv/DOI로 실제 존재를 검증해 docs/literature/와 references.bib에 남긴다."
hermes profile list
```

### 3-4. 직원마다 자기 봇 토큰 연결 (5번 반복)
`--clone`은 **PI의 토큰까지 복사**한다. 반드시 각자 자기 토큰으로 바꾼다.
```bash
hermes -p coder gateway setup      # Discord → coder 봇 토큰 → Allow yourself? y → Home channel Enter
hermes -p analyst gateway setup
hermes -p reviewer gateway setup
hermes -p writer gateway setup
hermes -p scholar gateway setup
```
각 직원의 모델이 PI와 같은지 확인한다. 로그인을 요구하면 같은 ChatGPT 계정으로 로그인한다:
```bash
for p in coder analyst reviewer writer scholar; do hermes -p $p chat -q "OK라고만 답해"; done
```

---

## 4. 팀으로 묶기

### 4-1. 팀 설정 파일 채우기
```bash
cd ~/Projects/hermes-team
nano team.json            # guild_id, category_id, lobby_channels 를 기록표 값으로
nano souls/_team_ids.md   # 7개 ID (나 + 봇 6개) 를 기록표 값으로. 형식: `<@숫자>`
```
`team.json` 예:
```json
{
  "guild_id": "111111111111111111",
  "category_id": "222222222222222222",
  "projects_root": "~/Projects",
  "profiles": ["default", "coder", "analyst", "reviewer", "writer", "scholar"],
  "lobby_channels": ["333333333333333333"],
  "reasoning": {"default": "medium", "coder": "low", "analyst": "medium", "reviewer": "medium", "writer": "low", "scholar": "low"}
}
```

### 4-2. 한 번에 적용
```bash
cd ~/Projects/hermes-team
python3 tools/lab.py env         # 6명 .env: 봇끼리 멘션 허용, 허용 사용자 = 나 + 봇 6개
python3 tools/lab.py reasoning   # 추론 수준: PI·analyst·reviewer medium / coder·writer·scholar low
python3 newproject.py sync       # 6명 config.yaml: 로비·프로젝트 채널 연결 (PI만 멘션 없이 응답)
bash install_souls.sh            # 6명 SOUL(역할·규칙) 설치 + 게이트웨이 재시작
```
- `lab.py env`가 설정하는 값: `DISCORD_ALLOW_BOTS=mentions`, `DISCORD_IGNORE_NO_MENTION=true`, `DISCORD_THREAD_REQUIRE_MENTION=true`, `DISCORD_ALLOWED_USERS=<7개 ID>`. 원본은 `.env.bak`으로 남긴다.
- `install_souls.sh`가 "주의: 채우지 않은 ID"를 출력하면 4-1로 돌아간다.

### 4-3. 직원 봇의 slash 명령 등록 (처음 한 번)
복제한 profile은 PI의 "명령 등록 완료" 기록까지 복사돼서 `/reset` 같은 명령이 등록되지 않는다. 한 번만 강제로 등록한다:
```bash
for p in coder analyst reviewer writer scholar; do echo 'DISCORD_COMMAND_SYNC_POLICY=bulk' >> ~/.hermes/profiles/$p/.env; done
hermes gateway restart --all
sleep 30
grep -h -i 'Synced.*slash' ~/.hermes/profiles/*/logs/gateway.log | tail -n 5
for p in coder analyst reviewer writer scholar; do sed -i '/^DISCORD_COMMAND_SYNC_POLICY=bulk$/d' ~/.hermes/profiles/$p/.env; done
hermes gateway restart --all
```
Discord에서 `Ctrl+R`로 새로고침하고 `/`를 입력했을 때 봇마다 명령 목록이 보이면 된다.

### 4-4. PI에게 채널 만들 권한 주기
Discord에서 `Projects` 카테고리 우클릭 → **카테고리 편집 → 권한** → 멤버 추가 `hermes-researcher` → **채널 관리** 허용 → 저장.
(서버 전체 권한이 아니라 이 카테고리 안에서만 허용하는 것이 안전하다.)

### 4-5. Antigravity 읽기 권한
`agy -p` 같은 헤드리스 실행은 허용되지 않은 사이트 읽기를 **오류 없이 조용히 거부**한다. 학술 사이트 읽기만 허용하고 페이지 조작은 막는다:
```bash
python3 ~/Projects/hermes-team/tools/lab.py agy-perms
```
`extras/antigravity-permissions.json`의 규칙(학술 도메인 20개 `read_url`, `execute_url(*)` 거부)을 `~/.gemini/antigravity-cli/settings.json`에 합친다. 기존 규칙은 유지되고, 원본은 `settings.json.bak`으로 남는다.

### 4-6. PI 홈 채널 + 아침 브리핑
1. Discord `#hermes`에서 `@hermes-researcher /sethome` (자동완성에서 **APP** 표시가 있는 항목을 고른다)
2. 매일 09:00 브리핑은 4-7의 `install_extras.sh`가 같이 등록한다. 상태 수집은 스크립트가, 정리는 Claude(sonnet, 읽기 전용)가 하고 PI 모델은 쓰지 않는다(`--no-agent`, 출력을 그대로 전달). 등록 뒤 확인:
   ```bash
   hermes cron status          # Next run 이 내일 09:00 (+09:00) 인지 확인. 9시간 어긋나면 "0 0 * * *" 로 다시 만든다
   hermes cron run morning-brief   # 지금 한 번 시험 → 1~3분 뒤 #hermes 에 브리핑
   ```
3. 브리핑은 Discord에서 언제든 받을 수 있다: PI 봇의 **`/brief`** (플러그인 lab-handoff, 4-7에서 설치). PI 모델을 거치지 않고 Claude가 정리해 **보낸 채널에** 올린다. 프로젝트 채널에서는 그 프로젝트만, `#hermes`에서는 전체, `/brief <프로젝트>`로 골라서도 된다.

### 4-7. 차단 감시 + PI 대화 인계 (PI 판단에 맡기지 않는 자동 장치)
- **차단 감시** (`extras/block-watch.sh`, 10분마다): 같은 카드가 2번 이상 block되거나 triage로 가면 Claude가 원인을 진단하고, 허용 범위 안의 해결은 바로 한다. 결과(원인·한 일·commit·남은 것·연구자 결정 필요)는 `#hermes`로 보낸다.
  - 바로 하는 것: 실행 권한, 검토된 코드와 명세의 기계적 불일치(command·code_commit), 카드 정리(코멘트·중복 archive·unblock·coder 카드 생성), 그 commit(`block-watch:`로 시작, main만).
  - 하지 않는 것: 승인 필드, `research/`·`results/`·`src/`, 실험·preflight 실행, 브랜치, push, Hermes 설정. `research/`·`results/`·`src/`는 Claude 권한에서도 막혀 있다. 사후 점검에서 이런 변경이 보이면 ⚠로 알리기만 하고 되돌리지는 않는다.
  - 같은 카드의 자동 해결은 2번까지(`MAX_FIXES`)이고, 그 뒤로는 진단만 한다. HEAD가 main이 아니어도 진단만 한다. 로그는 `<프로젝트>/docs/diagnosis/`에 남는다. 새로 볼 카드가 없으면 아무것도 보내지 않는다.
- **PI 대화 인계**: 대화가 길어지면 PI(로컬 모델)가 SOUL 규칙을 놓치므로, 대화를 끊어도 잃지 않게 한다.
  1. PI 대화가 압축될 때마다 hook `pi-handoff`가 `extras/pi-handoff.sh`를 돌린다. Claude(sonnet, 읽기 전용)는 대화 전체와 보드·git을 읽고 `state/pi-handoff.md`(인계 노트)를 다시 쓴다.
  2. 압축이 3번 이상이면 `state/pi-reset-requested`를 만든다. 그러면 플러그인 `lab-handoff`가 그 채널의 다음 사용자 메시지에서 `/new`와 같은 경로로 새 대화를 연다.
  3. 새 PI 대화의 시스템 프롬프트에는 플러그인이 인계 노트를 자동으로 넣는다(최대 4,000자).
  4. PI의 매 턴 메시지 끝에는 플러그인이 핵심 규칙 `souls/pi-rules.md`(7줄, 약 800자)를 붙인다. SOUL은 대화 맨 앞에 있어 긴 대화에서 묻히므로, 가장 최근 위치에 리마인더를 두는 것이다. 파일을 고치면 다음 턴부터 반영된다(재시작·`/new` 불필요). 다른 직원에게는 붙지 않는다.
  5. PI가 카드를 `kanban_create` 도구가 아니라 터미널 명령(`hermes kanban create`)으로 만들면 완료 알림 구독이 빠져 PI가 완료를 모른다. `execute_code` 안에서 subprocess로 부른 경우도 같다. 플러그인이 그 명령 결과(`Created t_…` 또는 `--json`의 `"id"`)에서 카드 번호를 읽어, 그 프로젝트 채널을 구독시킨다 (구독이 하나도 없는 새 프로젝트는 `projects.json`·`team.json`·`_team_ids.md`로 만든다). 확인: `grep -hE "lab-handoff: (terminal|subscribed|no channel)" ~/.hermes/logs/*.log`
  - 인계 노트는 직접 `/new`해도 들어간다. 압축 기준 횟수는 `RESET_AFTER`(pi-handoff.sh)에서 바꾼다. 실행 기록은 `logs/handoff/`에 남는다.
설치 (아침 브리핑까지 한 번에. 여러 번 실행해도 되고, `extras/`를 고친 뒤에도 다시 실행한다):
```bash
bash ~/Projects/hermes-team/extras/install_extras.sh
bash ~/Projects/hermes-team/install_souls.sh      # 게이트웨이 재시작 → hook·플러그인 적용
```
확인: `hermes plugins list | grep lab-handoff`(enabled), 게이트웨이 로그에 `[hooks]` 로드 오류가 없는지(`grep -i "pi-handoff\|lab-handoff" ~/.hermes/logs/agent.log | tail`).

### 4-8. 직원 기억 가져오기 (내 연구실을 다시 설치할 때만)
직원들이 쌓은 장기 기억(교훈·선호)은 `memories/<profile>/`에 들어 있다. 다시 설치할 때 가져온다:
```bash
bash ~/Projects/hermes-team/tools/memories.sh import
bash ~/Projects/hermes-team/install_souls.sh
```
`memories/`는 git에 올라가지 않는다(내 PC 전용). 기억은 직원이 계속 고치므로 다시 설치하기 전에 `bash tools/memories.sh export`로 최신본을 받아 두고, 이 폴더를 따로 보관한다 (또는 부록 A의 `hermes backup`).

### 4-9. 재부팅 후에도 계속 돌게 하기
```bash
sudo loginctl enable-linger $USER
hermes gateway status
```
원래 PC에서는 게이트웨이가 **`hermes-gateway.service`** 라는 systemd 서비스로 돈다 (`hermes gateway status` 첫 줄에 보인다). 새 PC에서 `running`이 아니면 `hermes gateway --help`에서 시작이나 서비스 설치 명령을 확인해 실행한다. 게이트웨이 **하나가 6명 모두를 맡는다** (`serving profiles default, coder, ...`).

---

## 5. 점검

### 5-1. 자동 점검
```bash
python3 ~/Projects/hermes-team/tools/lab.py check
```
도구, 팀 설정, 6명의 토큰 중복 여부, `.env` 협업 설정, SOUL 최신 여부, 채널 연결, 추론 수준, 게이트웨이, 아침 브리핑, Antigravity 권한을 확인한다. 아무것도 바꾸지 않는다. 마지막 줄이 `READY`면 통과다. `WARN` 줄에는 고치는 명령이 함께 나온다.

### 5-2. Discord 시험
| # | 어디서 | 보낼 메시지 | 기대 결과 |
|---|---|---|---|
| 1 | `#hermes` | `넌 누구야?` (멘션 없이) | PI만 답한다 |
| 2 | `#hermes` | `@coder 넌 누구야?` | coder만 답한다. PI는 `—`만 보내거나 조용하다 |
| 3 | `#hermes` | analyst, reviewer, writer, scholar에게도 2번처럼 | 각자 자기 역할을 소개한다 |
| 4 | `#hermes` | `새 프로젝트 만들자: 간단한 선형회귀 데모` | PI가 이름·태그를 제안 → "좋아" → `Projects`에 새 채널, `~/Projects/<이름>`, kanban 보드가 생기고 링크를 보고한다. **보고 직후 게이트웨이가 15초 뒤 재시작된다** (새 채널 연결을 읽으려고) |
| 5 | 새 프로젝트 채널 (4번 후 **30초쯤 기다렸다가**) | `상태 알려줘` | 첫 줄에 `[태그]`, 표 형식 상태 보고. PI는 새 채널에서 먼저 말을 걸지 않으므로 내가 첫 메시지를 보낸다 |
| 6 | 새 프로젝트 채널 | `데이터 생성 스크립트 하나 만들어줘` | PI가 카드 생성 → coder가 Claude Code로 작성 → reviewer 검토 → PI가 main에 commit (승인 불필요) |
| 7 | 새 프로젝트 채널 | `@coder 기억해: 코드 스타일 — 타입 힌트 필수` | 답 끝에 `기억함: ...` |

6번 진행 상황은 터미널에서 볼 수 있다: `hermes kanban --board <프로젝트> list`

**반응이 없을 때**
1. 재시작 중일 수 있다 — 30초~1분 기다렸다가 다시 보낸다. 확인: `hermes gateway status`
2. 그래도 조용하면 그 채널에서 그 봇에게 `/reset` (`/` 입력 → 봇별 명령 목록에서 그 봇의 `/reset`) 후 다시 보낸다. 이전 대화가 옛 설정·옛 SOUL을 붙잡고 있을 때 생긴다
3. 그래도 안 되면 `python3 ~/Projects/hermes-team/newproject.py list`로 채널이 등록됐는지, `python3 tools/lab.py check`로 채널 연결 블록이 있는지 확인하고 `hermes gateway restart --all`

---

## 6. 매일 쓰는 법 (요약)

| 하고 싶은 것 | 방법 |
|---|---|
| 새 연구 주제 시작 | `#hermes`에서 PI에게 주제를 말한다 → 이름·태그 확인 → PI가 채널·폴더·보드를 만들고 **게이트웨이가 15초 뒤 재시작된다** → 30초쯤 뒤 새 채널에서 내가 첫 메시지를 보낸다 (반응이 없으면 그 채널에서 `/reset`) |
| 진행 상황·오늘 할 일 | PI 봇의 `/brief` — 프로젝트 채널은 그 프로젝트만, `#hermes`는 전체 (Claude가 정리, 1분 안팎), 매일 09:00 자동 브리핑, 또는 프로젝트 채널에서 `진행 상황 알려줘` |
| 특정 직원에게 직접 | `@analyst ...`처럼 멘션한다 (PI는 끼어들지 않는다) |
| 승인 | **Phase 시작**을 승인하면 그 Phase 안의 카드·검토·commit·계획된 실험의 실행 승인은 PI가 한다 (`approved_by: "PI (위임: …)"`로 기록). 내가 답하는 것: FINDINGS·HYPOTHESES·목표 변경, 다음 Phase 시작, 계획에 없는 실험, 자원 한도 초과, 삭제·revert, `uv add` |
| 보고 | PI는 Phase가 끝날 때와 막혔을 때(수정 요청 2번, 차단 감시의 결정 필요, 위임 밖 결정)만 보고한다. 중간이 궁금하면 묻거나 `/brief` |
| 결과 반영 | 브랜치는 쓰지 않는다. commit은 PI가 main에 알아서 한다 (승인 불필요) |
| 막힌 카드 | 2번 막히거나 triage로 가면 차단 감시가 Claude 진단·해결 결과를 `#hermes`에 올린다. "연구자 결정 필요"에만 답한다. 직접 보려면 `hermes kanban --board <프로젝트> list` |
| 규칙(SOUL) 수정 | `souls/<역할>.md`를 고친다 (이름은 `{{연구자}}`) → `bash install_souls.sh` → 그 채널에서 그 봇에게 `/reset`. PI 핵심 규칙 `souls/pi-rules.md`는 고치면 바로 반영 |
| 설정 전체 점검 | `python3 tools/lab.py check` |
| 프로젝트 정리 | `python3 newproject.py remove <이름>` — 등록·채널 연결 해제, 보드 정리, Discord 채널은 `archive-<이름>`으로 변경, 폴더는 `_archive/`로 보관. 완전 삭제는 `--delete-channel --purge`. 미리보기 `--dry-run` |

---

## 부록 A. 지금 연구실을 다른 PC로 옮기기

같은 봇과 같은 프로젝트를 그대로 쓰는 경우다.

1. **새 PC**에서 1-1 ~ 1-5를 한다 (도구 설치, Claude·Antigravity 로그인).
2. **원래 PC**에서 백업한다:
   ```bash
   hermes backup                         # ~/hermes-backup-<시각>.zip (설정, 토큰, 기억, 스킬, 세션, profile 전부)
   tar czf ~/projects.tgz -C ~ Projects  # hermes-team + 모든 연구 프로젝트
   ```
   백업이 끝날 때 나오는 **빠진 파일 보고**를 확인한다.
3. **원래 PC의 게이트웨이를 멈춘다.** 같은 토큰으로 두 곳이 동시에 접속하면 안 된다.
4. **새 PC**에서 복원한다:
   ```bash
   hermes import ~/hermes-backup-<시각>.zip
   tar xzf ~/projects.tgz -C ~
   ```
5. **사용자 이름(홈 경로)이 바뀌었다면** `projects.json`의 `"path"`를 새 경로로 고친 뒤 채널 연결을 다시 만든다:
   ```bash
   cd ~/Projects/hermes-team
   sed -i "s#/home/<예전사용자>/#$HOME/#g" projects.json
   python3 newproject.py sync
   ```
6. `python3 tools/lab.py agy-perms`, `bash extras/install_extras.sh`를 한다 (cron이 백업에 포함돼 있으면 이미 있다고 건너뛴다). 기억은 백업에 들어 있으므로 4-8은 하지 않는다.
7. `bash install_souls.sh` → `python3 tools/lab.py check` → 5-2 시험.

> `hermes backup` zip에는 **봇 토큰과 로그인 정보가 들어 있다.** 옮긴 뒤에는 지운다.

## 부록 B. 다른 사람에게 넘기기 (넘겨주는 쪽)

이 폴더(`hermes-team`) 자체가 GitHub 저장소다. 받는 사람에게 저장소 주소만 알려 주면 1-6부터 따라 한다. 내가 고친 규칙·스크립트는 내가 push하면 받는 사람이 `git pull`로 받는다.

- git에 올라가는 것: SOUL·템플릿 원본(연구자 이름은 `{{연구자}}`), 스크립트, 플러그인, 문서.
- 올라가지 않는 것: `team.json`, `souls/_team_ids.md`, `projects.json`, `memories/`, `state/`, `logs/`, 슬라이드(pptx).
- commit할 때 `tools/git-hooks/pre-commit`이 연구자 이름·Discord ID·홈 경로·위 파일을 검사해서 섞이면 막는다.
- 인터넷 없이 파일로 넘겨야 할 때만 예전 방식(`bash tools/make_handover.sh` → `~/Projects/hermes-team-share.tar`)을 쓴다.

## 부록 C. 예비 모델 (선택)

ChatGPT 한도가 차면 **예비 모델 없이도** 카드가 실패로 세지 않고 대기열에서 기다리다가, 한도가 풀리면 자동으로 다시 시작한다.
**고장 난 예비 모델은 오히려 해롭다.** 예비 모델이 실패하면 진짜 실패로 세어지고, 2번 실패하면 카드가 `blocked`가 된다. 예비 모델을 붙이려면 이 순서를 지킨다:
1. 단독 시험: `hermes chat --provider <provider> -m <모델> -q "OK라고만 답해"`
2. 통과했을 때만 6명에게 추가: `for p in default coder analyst reviewer writer scholar; do hermes -p $p fallback add <provider> <모델>; done`
3. 문제가 생기면 즉시 비운다: `for p in default coder analyst reviewer writer scholar; do hermes -p $p fallback clear; done`

GitHub Copilot 메모: `403 not licensed` → 구독(학생 혜택 포함)이 활성화되지 않음. `400 model not available for integrator` → 그 모델을 이 연결로는 못 씀. https://github.com/settings/copilot/features 에서 모델을 켠 뒤 1번부터 다시.

## 부록 D. 문제 해결

| 증상 | 원인 / 해결 |
|---|---|
| 자동완성에 봇이 안 보임 | 서버에 초대되지 않음 → 3-1의 4번을 **그 봇의** Application ID로 다시 |
| 멘션했는데 반응이 없음 | 역할(role)을 고름 → 자동완성에서 **APP** 표시 항목을 고르거나 `<@봇ID>`를 직접 입력 |
| 봇이 오프라인 / 한 봇을 켜면 다른 봇이 꺼짐 | 토큰 중복 (`--clone`이 PI 토큰을 복사) → `lab.py check`로 확인 → 3-4 다시 |
| PI가 멘션해도 직원이 무시함 | `.env` 협업 설정 → `python3 tools/lab.py env` 후 재시작 |
| 다른 직원만 멘션했는데 PI도 답함 | 정상 동작은 `—` 한 글자다. 길게 답하면 PI SOUL이 옛것 → `install_souls.sh` + `/reset` |
| 규칙을 바꿨는데 예전처럼 행동함 | 이미 열린 대화는 예전 SOUL을 가지고 있다 → 그 채널에서 그 봇에게 `/reset` (칸반 작업과 브리핑은 자동으로 새 SOUL을 씀) |
| `config.yaml`을 고쳤는데 그대로 | `# discord:`로 시작하는 주석 예시를 고친 것. discord 설정은 `newproject.py sync`가 관리한다 |
| 새 프로젝트 만들 때 HTTP 403 | 4-4 카테고리 권한, `team.json`의 `category_id` 확인 |
| 카드 결과 파일이 사라짐 | workspace가 `scratch`였음 → 항상 `dir:<프로젝트 경로>` (PI SOUL에 규칙 있음) |
| `429` / rate limit | ChatGPT 한도. 카드는 대기했다가 자동 재개된다. 기다리면 된다 |
| 카드가 `blocked` | 같은 원인으로 2번 실패함. 원인을 고친 뒤 `hermes kanban --board <p> unblock <id>` |
| 브리핑 로그에 `BLOCKED: script execution via -e/-c` | 무인 실행에서는 `python -c` 같은 명령이 막힌다. 에이전트가 다른 방법으로 다시 시도하므로 무시해도 된다 |
| `git switch main` 실패 | 저장소 기본 브랜치가 `master`다 → `git branch`로 확인. 1-1의 `init.defaultBranch main`을 해 두면 새 저장소는 main이 된다 |
| `uv` 없음 / `.venv` 깨짐 | 프로젝트에서 `bash scripts/researchctl doctor --fix` |
| 그 밖의 문제 | `hermes doctor`, 로그: PI는 `~/.hermes/logs/`, 직원은 `~/.hermes/profiles/<이름>/logs/` |

## 부록 E. 파일 지도

```text
~/Projects/hermes-team/            ← 연구실 "설계도" (이 폴더만 옮기면 같은 연구실을 만들 수 있다)
├── INSTALL.md                     이 문서
├── SETUP.md                       처음 구축할 때의 단계별 기록 (참고용)
├── docs/Hermes_Lab_Overview.pptx  구조·직원별 동작 설명 슬라이드 (연구자 이름 포함, git 제외)
├── team.json                      Discord 서버·카테고리·로비 ID, 직원 목록, 추론 수준 (내 PC 전용, git 제외)
├── projects.json                  등록된 프로젝트 ↔ 채널 (newproject.py 가 관리, git 제외)
├── tools/git-hooks/pre-commit     commit에 연구자 이름·ID·홈 경로·내 PC 전용 파일이 섞이면 막는다
├── newproject.py                  새 프로젝트: 폴더+git+uv, 채널, 채널 연결, kanban 보드
├── install_souls.sh               souls/*.md + _team_ids.md → 6명의 SOUL.md, 재시작
├── souls/                         직원별 역할·규칙 원본 (pi, coder, analyst, reviewer, writer, scholar, _team_ids)
│                                  + pi-rules.md (PI 매 턴 리마인더, 설치 없이 바로 반영)
├── template/                      새 프로젝트 뼈대 (AGENTS.md, research/, experiments/, scripts/researchctl …)
├── tools/lab.py                   설치 도우미: env / reasoning / agy-perms / rename / check
├── set_name.sh                    연구자 이름 바꾸기 (받은 사람이 처음 한 번)
├── tools/make_handover.sh         배포용 hermes-team-share/ + .tar 만들기·갱신
├── memories/<profile>/            직원 장기 기억 사본 (tools/memories.sh export/import, git 제외)
├── tools/memories.sh              기억 내보내기·가져오기
├── extras/                        Antigravity 권한, 빈 설정 예시, 자동 장치 원본 (설치는 install_extras.sh, 4-7):
│   ├── llama/                     로컬 모델 서버 systemd 파일 (데스크탑용·서버용, LOCAL_MODEL.md)
│   ├── install_extras.sh          아래 스크립트·hook·플러그인 복사 + cron 등록 (여러 번 실행 가능)
│   ├── morning-brief.sh           아침 브리핑 (cron, Claude 정리)
│   ├── block-watch.sh             차단 감시 (cron, 2회 block·triage → Claude 진단·자동 해결)
│   ├── pi-handoff.sh              PI 인계 노트 작성 (압축 hook이 호출)
│   ├── hooks/pi-handoff/          → ~/.hermes/hooks/ (PI 대화 압축 시 pi-handoff.sh 실행)
│   └── plugins/lab-handoff/       → ~/.hermes/plugins/ (인계 노트 주입 + 긴 PI 대화 새로 시작 + 매 턴 규칙 리마인더 + 터미널로 만든 카드의 완료 알림 구독)
├── state/                         인계 노트 등 실행 중 상태 (git 제외)
├── logs/                          브리핑·진단·인계 실행 기록 (git 제외)

~/.hermes/                         ← Hermes 데이터 (PC마다 따로, 비밀 포함 — git에 올리지 않는다)
├── config.yaml  .env  SOUL.md     PI(default)
├── memories/                      PI 장기 기억
└── profiles/<직원>/               직원별 config.yaml, .env(봇 토큰), SOUL.md, memories/, logs/

~/Projects/<프로젝트>/             ← 연구 프로젝트 하나 (git 저장소)
├── AGENTS.md                      이 프로젝트에서 에이전트가 따를 규칙
├── research/                      RESEARCH_STATE, HYPOTHESES, FINDINGS … (승인 후에만 수정)
├── experiments/  results/  src/  docs/
└── scripts/researchctl            doctor / validate / list / setup
```
