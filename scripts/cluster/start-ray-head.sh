#!/usr/bin/env bash
# Run on the Ray head node.
set -euo pipefail

VLLM_IMAGE="${VLLM_IMAGE:-nvcr.io/nvidia/vllm:26.03.post1-py3}"
MN_IF_NAME="${MN_IF_NAME:-enp1s0f1np1}"
VLLM_HOST_IP="${VLLM_HOST_IP:-10.100.0.10}"
NFS_STORE="${NFS_STORE:-/home/mars/models}"
RUN_CLUSTER_SH="${RUN_CLUSTER_SH:-run_cluster.sh}"
if [[ ! -f "$RUN_CLUSTER_SH" && -f "$HOME/run_cluster.sh" ]]; then
  RUN_CLUSTER_SH="$HOME/run_cluster.sh"
fi

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

bash "$RUN_CLUSTER_SH" "$VLLM_IMAGE" "$VLLM_HOST_IP" --head "$NFS_STORE" \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e MASTER_ADDR=$VLLM_HOST_IP \
  -e RAY_memory_monitor_refresh_ms=0
