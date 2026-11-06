# Hermes AI Researcher — 시작용 폴더

Hermes를 연구 오케스트레이터로 두고 Claude Code/Codex를 작업자로 연결하는 AI Researcher 구축용 템플릿입니다.

> 주의: 이 폴더는 안전한 시작 템플릿입니다. 실제 Hermes/Claude/Codex 연결, HPC 설정, 계정 권한, GPU 실행 환경은 자동으로 구성하지 않습니다. 예시 설정을 현재 서버 환경에 맞게 검토한 뒤 적용하세요.

## 핵심 구상
- **Hermes**: 장기 연구 상태를 읽고 다음 작업을 계획하는 오케스트레이터
- **Claude Code / Codex**: 코드 분석, 구현, 테스트 등을 맡는 작업자
- **Slurm**: HPC에서 GPU/CPU 자원을 할당하고 작업을 실행하는 스케줄러
- **Research State**: 현재 가설, 알려진 결과, 미해결 질문을 기록하는 프로젝트 지식 베이스
- **Experiment Record**: 코드 버전·데이터 버전·설정·시드·결과를 묶어 재현성을 확보하는 기록

## 폴더 구조
```text
hermes_ai_researcher_starter/
├── README_ko.md
├── .gitignore
├── docs/                 # 아키텍처, 용어, 구축·운영·보안 문서
├── config/               # 프로젝트 설정, 정책, 자원 제한, 모니터링 설정
├── schemas/              # 실험 명세 JSON Schema
├── research/              # 현재 상태, 가설, 발견, 미해결 질문, 결정 기록
├── experiments/           # 실험 템플릿과 명세
├── results/               # 실험별 요약·metric·산출물 manifest 안내
├── skills/                # 스킬 템플릿과 검증 라이프사이클
├── scripts/               # 안전한 researchctl 골격, 명세 검증기
├── deployment/            # Slurm, systemd, cron 예시
├── monitoring/            # 로그·관측성 안내
└── .github/workflows/     # 실험 명세 자동 검증 예시
```

## 먼저 할 일
1. `docs/IMPLEMENTATION_PLAN_ko.md`를 읽고 1단계부터 진행합니다.
2. `config/project.yaml`에서 프로젝트 경로·실험 목적을 설정합니다.
3. `research/RESEARCH_STATE.md`와 `research/HYPOTHESES.md`에 현재 연구 상태를 입력합니다.
4. `experiments/templates/experiment.yaml`을 복사해 첫 실험 제안서를 만듭니다.
5. `scripts/validate_experiment.py`로 제안서 형식을 검증합니다.
6. GPU 실행은 사람이 확인하고 `deployment/slurm/gpu_job_template.sbatch`를 실제 서버 환경에 맞게 수정한 뒤 사용합니다.

## 중요한 구분
이 템플릿은 문서·정책·스키마·예시만 제공합니다. `researchctl`은 안전한 안내용 골격이며 실제 Slurm 제출이나 프로세스 종료를 수행하지 않습니다. 운영 명령을 추가할 때는 경로 제한, 사용자 확인, 로그 기록, 자원 제한을 먼저 구현하세요.
