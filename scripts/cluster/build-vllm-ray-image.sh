#!/usr/bin/env bash
# Build a vLLM Docker image variant that includes the Ray CLI required by run_cluster.sh.

set -euo pipefail

BASE_IMAGE="${BASE_IMAGE:-nvcr.io/nvidia/vllm:26.04-py3}"
OUTPUT_IMAGE="${OUTPUT_IMAGE:-vllm-ray:26.04-py3}"
RAY_PACKAGE="${RAY_PACKAGE:-ray[default]}"
DOCKER_BIN="${DOCKER_BIN:-docker}"

BUILD_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

cat > "$BUILD_DIR/Dockerfile" <<'EOF'
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG RAY_PACKAGE
RUN python3 -m pip install --no-cache-dir "${RAY_PACKAGE}" \
    && ray --version
EOF

echo "Base image:   $BASE_IMAGE"
echo "Output image: $OUTPUT_IMAGE"
echo "Ray package:  $RAY_PACKAGE"
echo

"$DOCKER_BIN" build \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  --build-arg RAY_PACKAGE="$RAY_PACKAGE" \
  -t "$OUTPUT_IMAGE" \
  "$BUILD_DIR"

echo
echo "Built $OUTPUT_IMAGE"
echo
echo "Use it with:"
echo "  sudo VLLM_IMAGE=$OUTPUT_IMAGE bash scripts/cluster/start-ray-head.sh"
echo "  sudo VLLM_IMAGE=$OUTPUT_IMAGE bash scripts/cluster/start-ray-worker.sh"
