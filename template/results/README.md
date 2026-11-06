# Results

실험마다 별도 폴더를 만드는 것을 권장합니다.

```text
results/
└── vqc_mlp_seed42_001/
    ├── summary.md
    ├── metrics.json
    ├── environment.txt
    └── artifact_manifest.txt
```

대용량 체크포인트와 데이터는 Git에 무조건 추가하지 마세요. 기관 저장 정책에 맞춰 별도 스토리지 또는 DVC를 검토하고, 결과 폴더에는 산출물 경로와 체크섬 등 manifest를 남길 수 있습니다.
