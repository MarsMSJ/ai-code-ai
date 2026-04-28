#!/usr/bin/env bash
# Run on each Spark worker node. Auto-detects the node's 100GbE IP.
set -euo pipefail

VLLM_IMAGE="${VLLM_IMAGE:-nvcr.io/nvidia/vllm:26.03.post1-py3}"
MN_IF_NAME="${MN_IF_NAME:-enp1s0f1np1}"
HEAD_IP="${HEAD_IP:-10.100.0.10}"
NFS_STORE="${NFS_STORE:-/home/mars/models}"
RUN_CLUSTER_SH="${RUN_CLUSTER_SH:-run_cluster.sh}"
if [[ ! -f "$RUN_CLUSTER_SH" && -f "$HOME/run_cluster.sh" ]]; then
  RUN_CLUSTER_SH="$HOME/run_cluster.sh"
fi

VLLM_HOST_IP=$(ip -4 -o addr show dev "$MN_IF_NAME" scope global | awk '{split($4, ip, "/"); print ip[1]; exit}')
if [[ -z "$VLLM_HOST_IP" ]]; then
  echo "ERROR: Could not detect IPv4 address on interface $MN_IF_NAME."
  exit 1
fi

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

bash "$RUN_CLUSTER_SH" "$VLLM_IMAGE" "$HEAD_IP" --worker "$NFS_STORE" \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e MASTER_ADDR=$HEAD_IP \
  -e RAY_memory_monitor_refresh_ms=0
