# Hermes AI 연구실 — 먼저 읽기

이 폴더는 Discord에서 AI 직원 6명(PI, coder, analyst, reviewer, writer, scholar)이 함께 연구를 진행하는 연구실 설정 묶음이다.

## 시작 순서
1. 이 저장소를 `~/Projects/hermes-team` 에 받는다
   ```bash
   mkdir -p ~/Projects && cd ~/Projects && git clone https://github.com/<저장소>.git hermes-team
   ```
2. 연구자 이름을 내 이름으로 바꾼다 (공백 없이, 한글 가능)
   ```bash
   cd ~/Projects/hermes-team && bash set_name.sh <내이름>
   ```
3. `INSTALL.pdf` (원본 `INSTALL.tex`)를 처음부터 따라 설치한다 — 마지막에 `python3 tools/lab.py check` 가 READY 면 끝

## 미리 준비할 것
ChatGPT 구독, Claude 구독, Google 계정, Discord 서버(관리자), Linux 컴퓨터, 로컬 모델용 GPU(16GB 이상, [`LOCAL_MODEL.md`](LOCAL_MODEL.md)).
봇 토큰과 로그인 정보는 이 묶음에 들어 있지 않다. 모두 직접 만든다.
