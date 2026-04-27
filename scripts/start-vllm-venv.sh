#!/usr/bin/env bash
# Run on HEAD node after all 4 nodes show in `ray status`.
# Requires .venv-tq already activated: source ~/.venv-tq/bin/activate

set -euo pipefail

HEAD_100G_IP="10.100.0.10"
MODEL_PATH="${MODEL_PATH:-/mnt/expac/models/MiniMaxAI/MiniMax-M2}"
VLLM_PORT=8000

CUDA13_LIB="/home/mars/.venv-tq/lib/python3.12/site-packages/nvidia/cu13/lib"
ln -sf "$CUDA13_LIB/libcudart.so.13" "$CUDA13_LIB/libcudart.so.12" 2>/dev/null || true
export LD_LIBRARY_PATH="$CUDA13_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export VLLM_HOST_IP="$HEAD_100G_IP"
export SAFETENSORS_FAST_GPU=1
export HF_HUB_ENABLE_XET=0
export HF_HUB_DOWNLOAD_TIMEOUT=600
export HF_HUB_DOWNLOAD_RETRY=10

vllm serve "$MODEL_PATH" \
    --trust-remote-code \
    --distributed-executor-backend ray \
    --tensor-parallel-size 4 \
    --gpu-memory-utilization 0.90 \
    --enable-auto-tool-choice --tool-call-parser minimax_m2 \
    --reasoning-parser minimax_m2_append_think \
    --host 0.0.0.0 --port "$VLLM_PORT"
