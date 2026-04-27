#!/usr/bin/env bash
# Run on HEAD node after all 4 ray nodes are up.
# Execs vllm serve inside the running head container.

set -euo pipefail

HEAD_100G_IP="10.100.0.10"
MODEL_PATH="/root/.cache/huggingface/MiniMaxAI/MiniMax-M2"
VLLM_PORT=8000

# Find the running node-* container
CONTAINER=$(docker ps --filter "name=node-" --format "{{.Names}}" | head -1)
if [[ -z "$CONTAINER" ]]; then
    echo "ERROR: No running node-* container found. Start the head node first."
    exit 1
fi
echo "Using container: $CONTAINER"

docker exec -it "$CONTAINER" bash -lc "
    export SAFETENSORS_FAST_GPU=1
    export VLLM_HOST_IP=$HEAD_100G_IP
    export HF_HUB_ENABLE_XET=0
    export HF_HUB_DOWNLOAD_TIMEOUT=600
    export HF_HUB_DOWNLOAD_RETRY=10

    vllm serve $MODEL_PATH \
        --trust-remote-code \
        --distributed-executor-backend ray \
        --tensor-parallel-size 4 \
        --gpu-memory-utilization 0.90 \
        --enable-auto-tool-choice --tool-call-parser minimax_m2 \
        --reasoning-parser minimax_m2_append_think \
        --host 0.0.0.0 --port $VLLM_PORT
"
