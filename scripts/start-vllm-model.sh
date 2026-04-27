#!/usr/bin/env bash
# Run vLLM for any model path visible inside the Ray head container.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <container-model-path> [served-model-name]"
  echo "Example: $0 /root/.cache/huggingface/MiniMaxAI/MiniMax-M2.7 MiniMax-M2.7"
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODEL_PATH="$1"
SERVED_MODEL_NAME="${2:-$(basename "$MODEL_PATH")}"

export MODEL_PATH
export SERVED_MODEL_NAME

exec bash "$SCRIPT_DIR/start-vllm.sh"
