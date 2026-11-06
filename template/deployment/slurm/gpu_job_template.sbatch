#!/usr/bin/env bash
#SBATCH --job-name=research-template
#SBATCH --partition=REPLACE_WITH_PARTITION
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

# TEMPLATE ONLY: inspect and edit before use.
# Create logs/ before submission if your cluster requires it.
# Confirm partition, GPU syntax, environment activation, paths, and limits locally.

echo "Job ID: ${SLURM_JOB_ID:-unknown}"
echo "Node: ${SLURMD_NODENAME:-unknown}"
echo "Start: $(date -Is)"
echo "Working directory: $(pwd)"

# Example:
# source /path/to/venv/bin/activate
# python /path/to/project/train.py --config /path/to/config.yaml

echo "Replace this placeholder with the approved experiment command."
echo "End: $(date -Is)"
