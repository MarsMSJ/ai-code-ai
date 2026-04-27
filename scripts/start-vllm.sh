#!/usr/bin/env bash
# Run MiniMax-M2.7 from the model path mounted into the Ray head container.
set -euo pipefail

HEAD_100G_IP="${HEAD_100G_IP:-10.100.0.10}"
VLLM_IMAGE_MATCH="${VLLM_IMAGE_MATCH:-nvidia}"
VLLM_CONTAINER="${VLLM_CONTAINER:-}"
MODEL_PATH="${MODEL_PATH:-/root/.cache/huggingface/MiniMaxAI/MiniMax-M2.7}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-MiniMax-M2.7}"

find_head_container() {
  local candidates candidate cmd

  candidates=$(docker ps --format '{{.ID}} {{.Image}} {{.Names}}' \
    | awk -v image_match="$VLLM_IMAGE_MATCH" '
      BEGIN { image_match = tolower(image_match) }
      {
        line = tolower($0)
        if (line ~ image_match || $3 ~ /^node-/) {
          print $1
        }
      }
    ')

  for candidate in $candidates; do
    cmd=$(docker inspect --format '{{json .Config.Entrypoint}} {{json .Config.Cmd}}' "$candidate")
    if [[ "$cmd" == *"--head"* ]]; then
      echo "$candidate"
      return 0
    fi

    if docker exec "$candidate" bash -lc 'ray status --address 127.0.0.1:6379 >/dev/null 2>&1'; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

if [[ -z "$VLLM_CONTAINER" ]]; then
  VLLM_CONTAINER=$(find_head_container || true)
fi

if [[ -z "$VLLM_CONTAINER" ]]; then
    echo "ERROR: No running Ray head container found. Start the head node first."
    exit 1
fi
echo "Container: $VLLM_CONTAINER"

docker exec -it "$VLLM_CONTAINER" bash -lc "
    export VLLM_HOST_IP=$HEAD_100G_IP
    export HF_HOME=/root/.cache/huggingface
    export SAFETENSORS_FAST_GPU=1
    export HF_HUB_ENABLE_XET=0

    vllm serve '$MODEL_PATH' \
        --served-model-name '$SERVED_MODEL_NAME' \
        --tensor-parallel-size 4 \
        --max-model-len 180000 \
        --kv-cache-dtype fp8 \
        --gpu-memory-utilization 0.90 \
        --enable-prefix-caching \
        --tool-call-parser minimax_m2 \
        --reasoning-parser minimax_m2 \
        --enable-auto-tool-choice \
        --trust-remote-code \
        --host 0.0.0.0 \
        --port 8000
"
