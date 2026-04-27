#!/usr/bin/env bash
# Run on each WORKER node (10.100.0.11-13)

set -euo pipefail

HEAD_100G_IP="10.100.0.10"
IFACE_100G="enp1s0f1np1"
VLLM_IMAGE="${VLLM_IMAGE:-nvcr.io/nvidia/vllm:26.03.post1-py3}"
HF_CACHE="${HF_CACHE:-/home/mars/.cache/huggingface}"

WORKER_100G_IP=$(ip -4 addr show "$IFACE_100G" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "Worker IP: $WORKER_100G_IP"

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

bash ~/run_cluster.sh "$VLLM_IMAGE" "$HEAD_100G_IP" --worker "$HF_CACHE" \
    -e VLLM_HOST_IP="$WORKER_100G_IP" \
    -e NCCL_SOCKET_IFNAME="$IFACE_100G" \
    -e GLOO_SOCKET_IFNAME="$IFACE_100G" \
    -e UCX_NET_DEVICES="$IFACE_100G" \
    -e MASTER_ADDR="$HEAD_100G_IP" \
    -e RAY_memory_monitor_refresh_ms=0 \
    -e RAY_DISABLE_METRICS=1
