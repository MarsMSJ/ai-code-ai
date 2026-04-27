#!/usr/bin/env bash
# Run on each WORKER node (192.168.1.121–127 / 10.10.0.2–8)
# Auto-detects this node's 100GbE IP and joins the Ray cluster.

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
HEAD_100G_IP="10.10.0.10"
IFACE_100G="enp1s0f1np1"
VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai:latest}"
HF_CACHE="${HF_CACHE:-/home/mars/.cache/huggingface}"
MODELS_DIR="${MODELS_DIR:-/home/mars/models}"
NFS_MOUNT="${NFS_MOUNT:-/mnt/expac}"
CONTAINER_NAME="spark"
RAY_PORT=6379
# ──────────────────────────────────────────────────────────────────────────────

echo "==> Detecting local 100GbE IP on $IFACE_100G..."
WORKER_100G_IP=$(ip -4 addr show "$IFACE_100G" 2>/dev/null \
    | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)

if [[ -z "$WORKER_100G_IP" ]]; then
    echo "ERROR: Could not determine IP on $IFACE_100G."
    echo "  Either the interface is wrong or has no IP assigned."
    echo "  Override: IFACE_100G=<iface> bash start-ray-worker.sh"
    exit 1
fi
echo "    Worker 100GbE IP: $WORKER_100G_IP"

echo "==> Dropping page cache..."
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

echo "==> Removing any existing '$CONTAINER_NAME' container..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "==> Starting Ray WORKER container ($VLLM_IMAGE)..."
docker run -d \
    --gpus all \
    --ipc=host \
    --network host \
    --name "$CONTAINER_NAME" \
    -e MASTER_ADDR="$HEAD_100G_IP" \
    -e MASTER_PORT=29500 \
    -e VLLM_HOST_IP="$WORKER_100G_IP" \
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
    -lc "ray start --address=$HEAD_100G_IP:$RAY_PORT --block"

echo ""
echo "Worker $WORKER_100G_IP started. Check from head node:"
echo "  docker exec -it spark ray status"
