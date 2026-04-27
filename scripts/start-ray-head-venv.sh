#!/usr/bin/env bash
# Run on HEAD node: spark-50e0 (192.168.1.120 / 10.10.0.1)
# Starts Ray head using the vLLM venv (no Docker).

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
HEAD_100G_IP="10.10.0.1"
IFACE_100G="enp1s0f1np1"
VENV_PATH="${VENV_PATH:-/home/mars/.venv-tq}"   # override if venv is on NFS: VENV_PATH=/mnt/expac/venv-tq
RAY_PORT=6379
RAY_DASHBOARD_PORT=8265
# ──────────────────────────────────────────────────────────────────────────────

RAY="$VENV_PATH/bin/ray"

if [[ ! -x "$RAY" ]]; then
    echo "ERROR: ray not found at $RAY"
    echo "  Set VENV_PATH= to the directory created by: uv venv --python 3.12 .venv-tq"
    exit 1
fi

echo "==> Dropping page cache..."
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

echo "==> Stopping any existing Ray instance..."
"$RAY" stop --force 2>/dev/null || true
sleep 2

echo "==> Starting Ray HEAD (port $RAY_PORT)..."
export GLOO_SOCKET_IFNAME="$IFACE_100G"
export NCCL_SOCKET_IFNAME="$IFACE_100G"
export UCX_NET_DEVICES="$IFACE_100G"

"$RAY" start \
    --head \
    --port="$RAY_PORT" \
    --dashboard-port="$RAY_DASHBOARD_PORT" \
    --node-ip-address="$HEAD_100G_IP" \
    --object-manager-port=8076 \
    --node-manager-port=8077 \
    --ray-client-server-port=10001

echo ""
"$RAY" status

echo ""
echo "Ray head is up at $HEAD_100G_IP:$RAY_PORT"
echo "Next: run start-ray-worker-venv.sh on each worker node, then start-vllm-venv.sh here."
