#!/usr/bin/env bash
# Run on HEAD node: spark-50e0 (192.168.1.120 / 10.100.0.10)

set -euo pipefail

HEAD_WAN_IP="192.168.1.120"
HEAD_100G_IP="10.100.0.10"
IFACE_100G="enp1s0f1np1"
VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai:26.03.post1-py3}"
HF_CACHE="${HF_CACHE:-/home/mars/.cache/huggingface}"

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

bash ~/run_cluster.sh "$VLLM_IMAGE" "$HEAD_100G_IP" --head "$HF_CACHE" \
    -e VLLM_HOST_IP="$HEAD_100G_IP" \
    -e NCCL_SOCKET_IFNAME="$IFACE_100G" \
    -e GLOO_SOCKET_IFNAME="$IFACE_100G" \
    -e UCX_NET_DEVICES="$IFACE_100G" \
    -e MASTER_ADDR="$HEAD_100G_IP" \
    -e RAY_memory_monitor_refresh_ms=0 \
    -e RAY_DISABLE_METRICS=1
