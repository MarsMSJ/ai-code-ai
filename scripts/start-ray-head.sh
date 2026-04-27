#!/usr/bin/env bash
# Run on HEAD node: spark-50e0 (192.168.1.120 / 10.10.0.1)
# Starts the Ray head container for MiniMax-M2 inference.

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
HEAD_WAN_IP="192.168.1.120"
HEAD_100G_IP="10.10.0.1"
IFACE_100G="enp1s0f1np1"
VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai:latest}"
HF_CACHE="${HF_CACHE:-/home/mars/.cache/huggingface}"
MODELS_DIR="${MODELS_DIR:-/home/mars/models}"
NFS_MOUNT="${NFS_MOUNT:-/mnt/expac}"
CONTAINER_NAME="spark"
RAY_PORT=6379
VLLM_PORT=8000
# ──────────────────────────────────────────────────────────────────────────────

echo "==> Dropping page cache..."
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

echo "==> Removing any existing '$CONTAINER_NAME' container..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "==> Starting Ray HEAD container ($VLLM_IMAGE)..."
docker run -d \
    --gpus all \
    --ipc=host \
    --network host \
    --name "$CONTAINER_NAME" \
    -e MASTER_ADDR="$HEAD_100G_IP" \
    -e MASTER_PORT=29500 \
    -e VLLM_HOST_IP="$HEAD_100G_IP" \
    -e GLOO_SOCKET_IFNAME="$IFACE_100G" \
    -e NCCL_SOCKET_IFNAME="$IFACE_100G" \
    -e UCX_NET_DEVICES="$IFACE_100G" \
    -e TP_SOCKET_IFNAME="$IFACE_100G" \
    -e OMPI_MCA_btl_tcp_if_include="$IFACE_100G" \
    -e SAFETENSORS_FAST_GPU=1 \
    -e HF_HUB_ENABLE_XET=0 \
    -e HF_HUB_DOWNLOAD_TIMEOUT=600 \
    -e HF_HUB_DOWNLOAD_RETRY=10 \
    -e RAY_memory_monitor_refresh_ms=0 \
    -e RAY_DISABLE_METRICS=1 \
    -v "$HF_CACHE":/root/.cache/huggingface \
    -v "$MODELS_DIR":/vllm-workspace/models \
    -v "$NFS_MOUNT":/mnt/expac \
    --entrypoint /bin/bash \
    "$VLLM_IMAGE" \
    -lc "ray start --head --port=$RAY_PORT --block"

echo ""
echo "==> Waiting for Ray head to be ready..."
sleep 5
docker exec "$CONTAINER_NAME" ray status

echo ""
echo "Head node up. Next:"
echo "  1. Start workers on each node:  bash start-ray-worker.sh"
echo "  2. Once all 8 nodes show in ray status, serve the model:"
echo "     bash start-vllm.sh"
echo ""
echo "API will be available at http://$HEAD_WAN_IP:$VLLM_PORT/v1"
