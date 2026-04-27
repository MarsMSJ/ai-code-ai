#!/usr/bin/env bash
# Run on each WORKER node (10.100.0.11-13)
# Requires .venv-tq already activated: source ~/.venv-tq/bin/activate

set -euo pipefail

HEAD_100G_IP="10.100.0.10"
IFACE_100G="enp1s0f1np1"
RAY_PORT=6379

WORKER_100G_IP=$(ip -4 addr show "$IFACE_100G" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "Worker IP: $WORKER_100G_IP"

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

ray stop --force 2>/dev/null || true
sleep 2

CUDA_LIB="/usr/local/cuda-13.0/targets/sbsa-linux/lib"
mkdir -p /tmp/cuda-compat
ln -sf "$CUDA_LIB/libcudart.so.13" /tmp/cuda-compat/libcudart.so.12
export LD_LIBRARY_PATH="/tmp/cuda-compat:$CUDA_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export GLOO_SOCKET_IFNAME="$IFACE_100G"
export NCCL_SOCKET_IFNAME="$IFACE_100G"
export UCX_NET_DEVICES="$IFACE_100G"

ray start \
    --address="$HEAD_100G_IP:$RAY_PORT" \
    --node-ip-address="$WORKER_100G_IP" \
    --object-manager-port=8076 \
    --node-manager-port=8077 \
    --object-store-memory=10000000000
