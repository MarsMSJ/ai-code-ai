#!/usr/bin/env bash
# Run on HEAD node AFTER all 8 ray nodes show in `ray status`.
# Serves MiniMax-M2 using the vLLM venv directly (no Docker).

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
HEAD_100G_IP="10.100.0.10"
VENV_PATH="${VENV_PATH:-/home/mars/.venv-tq}"
MODEL_ID="MiniMaxAI/MiniMax-M2"
LOCAL_MODEL_PATH="${LOCAL_MODEL_PATH:-/mnt/expac/models/MiniMaxAI/MiniMax-M2}"
VLLM_PORT=8000
# ──────────────────────────────────────────────────────────────────────────────

VLLM="$VENV_PATH/bin/vllm"
RAY="$VENV_PATH/bin/ray"

if [[ ! -x "$VLLM" ]]; then
    echo "ERROR: vllm not found at $VLLM — check VENV_PATH"
    exit 1
fi

echo "==> Verifying Ray cluster has 8 nodes..."
NODE_COUNT=$("$RAY" status 2>&1 | grep -cP '1 GPU' || true)
if [[ "$NODE_COUNT" -lt 8 ]]; then
    echo "WARNING: Expected 8 GPU nodes, currently see $NODE_COUNT."
    "$RAY" status
    read -rp "  Continue anyway? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || exit 1
fi

echo "==> Checking for local model weights..."
if [[ -d "$LOCAL_MODEL_PATH" ]]; then
    echo "    Found local weights at $LOCAL_MODEL_PATH"
    SERVE_TARGET="$LOCAL_MODEL_PATH"
else
    echo "    No local weights at $LOCAL_MODEL_PATH — will use HF Hub ($MODEL_ID)"
    SERVE_TARGET="$MODEL_ID"
fi

export VLLM_HOST_IP="$HEAD_100G_IP"
export SAFETENSORS_FAST_GPU=1
export HF_HUB_ENABLE_XET=0
export HF_HUB_DOWNLOAD_TIMEOUT=600
export HF_HUB_DOWNLOAD_RETRY=10

echo "==> Launching vLLM server (TP=8 across Ray cluster)..."
echo "    Model:  $SERVE_TARGET"
echo "    Listen: 0.0.0.0:$VLLM_PORT"
echo ""

"$VLLM" serve "$SERVE_TARGET" \
    --trust-remote-code \
    --distributed-executor-backend ray \
    --tensor-parallel-size 4 \
    --enable-auto-tool-choice --tool-call-parser minimax_m2 \
    --reasoning-parser minimax_m2_append_think \
    --host 0.0.0.0 --port "$VLLM_PORT"
