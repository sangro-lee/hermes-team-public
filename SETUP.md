# Hermes 연구실 팀 설정 가이드

> **참고용 기록.** 이 문서는 연구실을 처음 구축하면서 단계별로 적은 기록이라 일부 내용이 현재와 다르다 (예: reviewer·writer의 작업 도구, 교차 검토, 장기 기억 규칙).
> **새 컴퓨터 설치는 [`INSTALL.pdf`](INSTALL.pdf)** (원본 `INSTALL.tex`), 구조 설명은 `docs/Hermes_Lab_Overview.pptx`를 본다.


| 직원 | profile | 역할 | 실제 작업 도구 |
|---|---|---|---|
| PI | `default` (봇: hermes-researcher) | 계획·배정·승인 요청·보고 | kanban |
| coder ✅ | `coder` | 코드 구현·수정 | `claude -p` |
| analyst | `analyst` | 실험 실행·분석·FINDINGS 수정안 | python, research-analysis 스킬 |
| reviewer | `reviewer` | 코드·결과·인용 교차 검토 | `agy -p` |
| writer | `writer` | 논문 초안 (`docs/paper/`) | arxiv, grounded-citations 스킬 |
| scholar | `scholar` | 문헌 조사·참고문헌 (`docs/literature/`) | `agy -p` + arxiv 스킬 |

**규칙: 멘션받은 봇만 대답한다.** PI와 대화할 때도 `@hermes-researcher`로 부른다.

---

## 사전 준비: uv (Python 환경 관리)

프로젝트마다 `pyproject.toml` + `uv.lock` → `.venv` 로 환경을 관리한다.
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh     # ~/.local/bin/uv
uv --version
```
- 환경 만들기/복원: 프로젝트에서 `scripts/researchctl setup` (= `uv sync`)
- 실행: `uv run python src/...` (activate 불필요)
- 패키지 추가: `uv add <패키지>` (에이전트는 승인 필요)

---

## A. 직원 한 명 만들기 (analyst, reviewer, writer 각각 반복)

아래에서 `<이름>`을 `analyst` / `reviewer` / `writer`로 바꿔서 한 명씩 끝까지 한다.

### A-1. Discord 앱 만들기
1. https://discord.com/developers/applications → **New Application** → 이름 `<이름>` → Create
2. 왼쪽 **Bot** → **Reset Token** → 토큰 복사 (메모장에 잠시 보관, 공유 금지)
3. 같은 화면 아래 **Message Content Intent** 켜기 → **Save Changes**
4. 왼쪽 **General Information** → **Application ID** 복사

### A-2. 서버에 초대
브라우저 주소창에 (`APP_ID`를 A-1-4의 값으로):
```text
https://discord.com/oauth2/authorize?scope=bot+applications.commands&permissions=274878024768&client_id=APP_ID
```
- 승인 화면 위쪽 봇 이름이 **`<이름>`인지 꼭 확인** (다른 봇이면 링크가 잘못된 것)
- 개인 서버 선택 → 승인
- 서버 오른쪽 멤버 목록에 `<이름>`(오프라인)이 보이면 성공
- 멤버 목록에서 봇 우클릭 → **사용자 ID 복사** → 메모

### A-3. Hermes profile 만들기
```bash
# analyst
hermes profile create analyst --clone \
  --description "실험 실행과 결과 분석 담당. 승인된 실험 명세만 실행하고, success_criteria 판정과 FINDINGS 수정안을 만든다. 코드는 수정하지 않는다."

# reviewer
hermes profile create reviewer --clone \
  --description "코드 변경, 분석 결과, 논문 초안의 수치와 인용을 교차 검토하는 담당. Antigravity(agy -p)로 두 번째 의견을 받는다. 직접 수정하지 않는다."

# writer
hermes profile create writer --clone \
  --description "논문·보고서 초안 작성 담당. results와 FINDINGS의 수치만 사용해 docs/paper/에 초안을 쓰고, 확인된 참고문헌만 인용한다. 코드와 연구 기록은 수정하지 않는다."
```

### A-4. 봇 토큰 연결
```bash
hermes -p <이름> gateway setup
```
- Discord 선택 → **A-1에서 복사한 `<이름>` 봇 토큰** 붙여 넣기 (PI 토큰 아님!)
- "Allow yourself?" → `y`
- Home channel → 비워 두고 Enter

### A-5. 모델 확인
```bash
hermes -p <이름> model
```
- ChatGPT가 이미 선택돼 있으면 그대로 종료
- 로그인을 요구하면 PI와 같은 ChatGPT 계정으로 로그인

### A-6. Discord 동작 설정
```bash
gvi ~/.hermes/profiles/<이름>/config.yaml
```
**파일 맨 아래에** 추가 (`#` 없이, `discord:`는 맨 앞, 아래 줄은 스페이스 2칸):
```yaml
discord:
  require_mention: true
  free_response_channels: ""
  auto_thread: false
```
> 파일 중간의 `# discord:` 로 시작하는 블록은 **주석(예시)** 이라 고쳐도 적용되지 않는다.

확인 (`discord:`가 한 번만 나와야 함):
```bash
grep -n -A3 '^discord:' ~/.hermes/profiles/<이름>/config.yaml
```

### A-7. slash 명령 등록 + 재시작 + 홈 채널
`--clone`이 PI의 "slash 명령 등록 완료" 기록까지 복사해서 새 봇의 `/new` 등이 등록되지 않는다. 처음 한 번만 강제 등록:
```bash
echo 'DISCORD_COMMAND_SYNC_POLICY=bulk' >> ~/.hermes/profiles/<이름>/.env
hermes gateway restart --all
hermes gateway list            # <이름> 이 목록에 있어야 함
grep -i 'Synced.*slash' ~/.hermes/profiles/<이름>/logs/gateway.log | tail -n 1   # "Synced NN slash command(s)" 확인
# 참고: ~/.hermes/logs/ 는 PI 로그, 직원 로그는 ~/.hermes/profiles/<이름>/logs/
```
Discord `Ctrl+R` 새로고침 → `/` 목록에 `<이름>`의 명령이 보이면, 추가한 줄을 지운다:
```bash
sed -i '/^DISCORD_COMMAND_SYNC_POLICY=bulk$/d' ~/.hermes/profiles/<이름>/.env
```
(명령 메뉴가 없어도 `@<이름> /new` 처럼 텍스트로 보내면 동작한다)

Discord 알림 채널(예: `#hermes-home`)에서 `@<이름>`(자동완성에서 **APP 표시 있는 항목** 선택) 멘션 후 `/sethome` 전송.

### A-8. 테스트
`#sandbox`에서 `@<이름>` (APP 항목 선택) `넌 누구야?`
- `<이름>` 봇만 답하면 성공 (PI는 조용해야 함)

---

## B. 봇끼리 대화 허용 (5명 모두 만든 뒤)

5개 profile의 `.env`에 추가:
```bash
gvi ~/.hermes/.env                       # PI
gvi ~/.hermes/profiles/coder/.env
gvi ~/.hermes/profiles/analyst/.env
gvi ~/.hermes/profiles/reviewer/.env
gvi ~/.hermes/profiles/writer/.env
```
각 파일에 (기존 `DISCORD_ALLOWED_USERS` 줄은 교체):
```bash
DISCORD_ALLOW_BOTS=mentions
DISCORD_IGNORE_NO_MENTION=true
DISCORD_THREAD_REQUIRE_MENTION=true
DISCORD_ALLOWED_USERS=내ID,PI봇ID,coder봇ID,analyst봇ID,reviewer봇ID,writer봇ID
```
그다음 `hermes gateway restart --all`.

토큰이 모두 다른지 확인 (5줄이 나오고 모두 달라야 함):
```bash
grep -H '^DISCORD_BOT_TOKEN' ~/.hermes/.env ~/.hermes/profiles/*/.env | cut -c1-70
```

---

## C. 프로젝트 자동 생성 준비 (PI가 채널·폴더·보드를 만들게 하기)

PI는 `newproject.py`로 새 프로젝트를 만든다: 템플릿 폴더 + git, Discord 채널, 모든 직원의 채널 연결(`channel_prompts`), kanban 보드.

### C-1. PI에게 '채널 관리' 권한 주기 (카테고리 한정 — 권장)
1. Discord 서버에 카테고리 **`Projects`** 만들기 (채널 목록 우클릭 → 카테고리 만들기)
2. `Projects` 카테고리 우클릭 → **카테고리 편집 → 권한 → 멤버/역할 추가 → `hermes-researcher`** → **채널 관리** 허용
3. 카테고리 우클릭 → **ID 복사** → `~/Projects/hermes-team/team.json`의 `"category_id": null` 을 `"category_id": "복사한ID"` 로 변경

> 서버 전체 '채널 관리'를 주는 것보다 안전하다. PI는 이 카테고리 안에서만 채널을 만든다.
> 새 채널은 카테고리 권한을 따르므로 직원 봇들도 자동으로 볼 수 있다.

### C-2. 기존 데모 프로젝트 등록 (채널을 자동 생성)
```bash
cd ~/Projects/hermes-team
python3 newproject.py adopt demo-sorting    --tag SORT --desc "삽입 정렬 vs sorted() 실행 시간 비교 (데모)"
python3 newproject.py adopt demo-montecarlo --tag MC   --desc "몬테카를로 π 추정 오차 분석 (데모)"
python3 newproject.py list
hermes gateway restart --all
```
- `adopt`는 폴더는 건드리지 않고, 채널 생성 + 등록 + 5개 profile의 `discord:` 설정 갱신 + 보드 생성을 한다.
- 각 profile `config.yaml`의 기존 `discord:` 블록은 스크립트가 관리하는 블록으로 교체된다 (원본은 `config.yaml.bak`).
- 이후 `discord:` 설정은 손으로 고치지 말고, 바꿀 게 있으면 `newproject.py`를 수정한 뒤 `python3 newproject.py sync`.

### C-3. 새 프로젝트 (평소 사용)
Discord에서 PI에게: `@hermes-researcher 새 프로젝트 만들자. 주제는 ...`
→ PI가 이름·태그·설명을 제안 → 확인하면 PI가 실행:
```bash
python3 ~/Projects/hermes-team/newproject.py create <이름> --tag <태그> --desc "<설명>" --restart
```
직접 실행해도 된다. 채널을 이미 만들었다면 `--channel-id <ID>`.

## D. SOUL(성격·역할) 설치

1. `~/Projects/hermes-team/souls/_team_ids.md`의 봇 ID 자리표시자(`RESEARCHER_USER_ID`, `PI_BOT_ID`, …)를 실제 값으로 바꾼다.
2. 설치:
```bash
cd ~/Projects/hermes-team/souls
bash ~/Projects/hermes-team/install_souls.sh     # 5명 설치 + 재시작
```

---

## F. 통합 테스트

| # | 채널 | 메시지 | 기대 |
|---|---|---|---|
| 1 | `#demo-sorting` | `@coder` `@analyst` `@reviewer` `@writer` 각각 `자기소개` | 각자 `[SORT]` + 자기 역할 |
| 2 | `#demo-sorting` | `@hermes-researcher 이 프로젝트 상태 알려줘` | PI만 응답, `[SORT]` |
| 3 | `#demo-sorting` | `@hermes-researcher analyst한테 실험 명세가 유효한지 물어봐줘` | PI가 `@analyst` 멘션 → analyst가 validate 결과로 답 |
| 4 | `#demo-montecarlo` | `@hermes-researcher 정렬 실험 결과 어때?` | `[MC]`, 다른 프로젝트라고 구분 |
| 5 | `#demo-sorting` | `@hermes-researcher bench_sort.py에 --sorted-input 옵션 추가해줘` | 카드 생성 → coder가 claude -p → 완료 알림 → PI가 diff 보고 + commit 승인 요청 |
| 6 | `#demo-sorting` | (5 이후 실험까지 끝나면) `@hermes-researcher 결과로 짧은 보고서 초안 써줘` | writer가 `docs/paper/draft.md` 작성 → reviewer 사실 확인 |
| 7 | `#sandbox` | `@hermes-researcher 새 프로젝트 만들자: 간단한 선형회귀 데모` | PI가 이름·태그 제안 → 확인 → `Projects` 카테고리에 새 채널 + `~/Projects/<이름>` + 보드 생성, 채널 링크 보고 |

---

## G. 문헌 조사 담당 scholar 추가

A단계(직원 만들기)를 `<이름>`=`scholar`로 그대로 한다. description:
```bash
hermes profile create scholar --clone \
  --description "문헌 조사 담당. 연구 질문·개선 아이디어에 대한 관련 논문을 찾고 Antigravity로 읽어 근거 위치와 함께 정리하며, arXiv/DOI로 실제 존재를 검증해 docs/literature/와 references.bib에 남긴다. 코드와 연구 기록은 수정하지 않는다."
```
그다음:
1. `~/Projects/hermes-team/team.json`의 `"profiles"`에 `"scholar"` 추가 → `python3 newproject.py sync` (모든 프로젝트 채널 연결)
2. `souls/_team_ids.md`에 `- scholar: \`<@SCHOLAR_BOT_ID>\`` 줄 추가 (실제 ID로) → `bash install_souls.sh`
3. scholar `.env`에도 B단계 설정 (`DISCORD_ALLOW_BOTS=mentions`, `DISCORD_ALLOWED_USERS`에 봇 ID들) — 다른 직원들의 `DISCORD_ALLOWED_USERS`에도 scholar 봇 ID 추가

### Antigravity 읽기 권한 (중요)
헤드리스 `agy -p`는 허용 안 된 URL 읽기를 **조용히 거부**한다. `~/.gemini/antigravity-cli/settings.json`의 `permissions`에 학술 도메인 읽기만 허용하고 클릭·입력은 막는다:
```json
"allow": [
  "read_url(arxiv.org)", "read_url(doi.org)", "read_url(semanticscholar.org)",
  "read_url(openreview.net)", "read_url(proceedings.mlr.press)", "read_url(neurips.cc)",
  "read_url(aps.org)", "read_url(quantum-journal.org)", "read_url(nature.com)",
  "read_url(iopscience.iop.org)", "read_url(sciencedirect.com)", "read_url(acm.org)",
  "read_url(ieee.org)", "read_url(springer.com)", "read_url(wiley.com)",
  "read_url(pennylane.ai)", "read_url(docs.pennylane.ai)", "read_url(quantum.cloud.ibm.com)",
  "read_url(github.com)", "read_url(scholar.google.com)"
],
"deny": [ "execute_url(*)" ]
```
(기존 `allow`/`deny` 배열에 **추가**한다. 문서상 `read_url`로 허용한 도메인은 터미널 샌드박스의 외부 접속 허용 목록에도 들어간다.)

## 문제 해결

| 증상 | 원인 / 해결 |
|---|---|
| 자동완성에 봇이 안 보임 | 서버 초대가 안 됨 → A-2를 그 봇의 Application ID로 다시 |
| 멘션했는데 무반응 | 역할(role)을 선택함 → **APP 표시** 항목 선택. 또는 `<@봇ID>` 직접 입력 |
| config 고쳤는데 그대로 | `# discord:` 주석 블록을 고친 것 → 맨 아래에 `#` 없이 추가 |
| 멘션 안 했는데 봇이 답함 | 그 봇의 `free_response_channels` 비우기 |
| 봇이 오프라인 / 다른 봇이 꺼짐 | 토큰 중복 (`--clone`이 PI 토큰을 복사함) → A-4 다시 |
| PI가 멘션해도 직원 무시 | B단계 `.env` 설정, `DISCORD_ALLOWED_USERS`에 PI 봇 ID |
| 봇끼리 계속 주고받음 | 내장 루프 가드(5분 내 20개)가 차단. SOUL의 "3번 넘으면 카드로" 규칙 |
| 새 프로젝트 생성 시 HTTP 403 | C-1 '채널 관리' 권한 / team.json `category_id` 확인 |
| 카드 결과 파일이 사라짐 | workspace가 `scratch` → `dir:<프로젝트 경로>` |
