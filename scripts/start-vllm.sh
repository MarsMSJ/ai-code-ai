#!/usr/bin/env bash
# Run on HEAD node AFTER all 8 ray nodes show in `ray status`.
# Execs vLLM serve inside the running 'spark' container.
#
# Model: MiniMaxAI/MiniMax-M2  (update MODEL_ID below for newer versions)
# Uses local model dir if /vllm-workspace/models/MiniMaxAI/MiniMax-M2 exists,
# otherwise falls back to HF Hub download.

set -euo pipefail

HEAD_100G_IP="10.10.0.10"
MODEL_ID="MiniMaxAI/MiniMax-M2"
LOCAL_MODEL_PATH="/vllm-workspace/models/MiniMaxAI/MiniMax-M2"
CONTAINER_NAME="spark"
VLLM_PORT=8000

echo "==> Verifying ray cluster has 8 nodes..."
NODE_COUNT=$(docker exec "$CONTAINER_NAME" ray status 2>&1 \
    | grep -cP '^\s+\d+\s+CPU' || true)
if [[ "$NODE_COUNT" -lt 8 ]]; then
    echo "WARNING: Expected 8 nodes but ray status shows $NODE_COUNT."
    echo "  Run: docker exec -it $CONTAINER_NAME ray status"
    read -rp "  Continue anyway? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || exit 1
fi

echo "==> Checking for local model weights..."
if docker exec "$CONTAINER_NAME" test -d "$LOCAL_MODEL_PATH" 2>/dev/null; then
    echo "    Found local weights at $LOCAL_MODEL_PATH"
    SERVE_TARGET="$LOCAL_MODEL_PATH"
else
    echo "    No local weights found. Will download from HF Hub ($MODEL_ID)."
    SERVE_TARGET="$MODEL_ID"
fi

echo "==> Launching vLLM server (TP=8 across Ray cluster)..."
docker exec -it "$CONTAINER_NAME" bash -lc "
    export SAFETENSORS_FAST_GPU=1
    export VLLM_HOST_IP=$HEAD_100G_IP
    export HF_HUB_ENABLE_XET=0
    export HF_HUB_DOWNLOAD_TIMEOUT=600
    export HF_HUB_DOWNLOAD_RETRY=10

    vllm serve $SERVE_TARGET \
        --trust-remote-code \
        --distributed-executor-backend ray \
        --tensor-parallel-size 4 \
        --enable-auto-tool-choice --tool-call-parser minimax_m2 \
        --reasoning-parser minimax_m2_append_think \
        --host 0.0.0.0 --port $VLLM_PORT
"
