#!/usr/bin/env bash
# Run on each WORKER node (192.168.1.121-123)

set -euo pipefail

VLLM_IMAGE="nvcr.io/nvidia/vllm:26.03.post1-py3"
MN_IF_NAME="enp1s0f1np1"
HEAD_IP="192.168.1.120"

WORKER_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)192\.168\.1\.\d+')
echo "Worker IP: $WORKER_IP"

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

bash ~/run_cluster.sh "$VLLM_IMAGE" "$HEAD_IP" --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP="$WORKER_IP" \
  -e UCX_NET_DEVICES="$MN_IF_NAME" \
  -e NCCL_SOCKET_IFNAME="$MN_IF_NAME" \
  -e OMPI_MCA_btl_tcp_if_include="$MN_IF_NAME" \
  -e GLOO_SOCKET_IFNAME="$MN_IF_NAME" \
  -e TP_SOCKET_IFNAME="$MN_IF_NAME" \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR="$HEAD_IP" \
  -e RAY_DISABLE_METRICS=1
