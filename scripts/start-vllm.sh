#!/usr/bin/env bash
# Run on head node after all 4 nodes are in ray status.
# Execs vllm serve inside the running head container.

HEAD_100G_IP="10.100.0.10"

CONTAINER=$(docker ps --filter "name=node-" --format "{{.Names}}" | head -1)
if [[ -z "$CONTAINER" ]]; then
    echo "ERROR: No running node-* container. Start the cluster first."
    exit 1
fi
echo "Container: $CONTAINER"

docker exec -it "$CONTAINER" bash -c "
    export VLLM_HOST_IP=$HEAD_100G_IP
    export HF_HOME=/root/.cache/huggingface
    export SAFETENSORS_FAST_GPU=1
    export HF_HUB_ENABLE_XET=0

    vllm serve MiniMaxAI/MiniMax-M2 \
        --trust-remote-code \
        --distributed-executor-backend ray \
        --tensor-parallel-size 4 \
        --gpu-memory-utilization 0.90 \
        --enable-auto-tool-choice --tool-call-parser minimax_m2 \
        --reasoning-parser minimax_m2_append_think \
        --host 0.0.0.0 --port 8000
"
