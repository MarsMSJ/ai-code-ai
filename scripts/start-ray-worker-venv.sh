#!/usr/bin/env bash
# Run on each WORKER node (192.168.1.121–127 / 10.10.0.2–8)
# Joins the Ray cluster using the vLLM venv (no Docker).

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
HEAD_100G_IP="10.10.0.1"
IFACE_100G="enp1s0f1np1"
VENV_PATH="${VENV_PATH:-/home/mars/.venv-tq}"   # or /mnt/expac/venv-tq if on NFS
RAY_PORT=6379
# ──────────────────────────────────────────────────────────────────────────────

RAY="$VENV_PATH/bin/ray"

if [[ ! -x "$RAY" ]]; then
    echo "ERROR: ray not found at $RAY"
    echo "  Set VENV_PATH= to the venv path, or install vllm on this node:"
    echo "    uv venv --python 3.12 .venv-tq && source .venv-tq/bin/activate && uv pip install vllm"
    exit 1
fi

echo "==> Detecting local 100GbE IP on $IFACE_100G..."
WORKER_100G_IP=$(ip -4 addr show "$IFACE_100G" 2>/dev/null \
    | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)

if [[ -z "$WORKER_100G_IP" ]]; then
    echo "ERROR: Could not determine IP on $IFACE_100G."
    echo "  Override: IFACE_100G=<iface> bash start-ray-worker-venv.sh"
    exit 1
fi
echo "    Worker 100GbE IP: $WORKER_100G_IP"

echo "==> Dropping page cache..."
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

echo "==> Stopping any existing Ray instance..."
"$RAY" stop --force 2>/dev/null || true
sleep 2

echo "==> Joining Ray cluster at $HEAD_100G_IP:$RAY_PORT..."
export GLOO_SOCKET_IFNAME="$IFACE_100G"
export NCCL_SOCKET_IFNAME="$IFACE_100G"
export UCX_NET_DEVICES="$IFACE_100G"

"$RAY" start \
    --address="$HEAD_100G_IP:$RAY_PORT" \
    --node-ip-address="$WORKER_100G_IP" \
    --object-manager-port=8076 \
    --node-manager-port=8077

echo ""
echo "Worker $WORKER_100G_IP joined. Verify from head:"
echo "  $RAY status"
