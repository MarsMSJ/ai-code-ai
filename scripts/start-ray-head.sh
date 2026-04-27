#!/usr/bin/env bash
# Run LAST on head node (10.100.0.10). Workers must already be running.

VLLM_IMAGE="nvcr.io/nvidia/vllm:26.03.post1-py3"
MN_IF_NAME="enp1s0f1np1"
VLLM_HOST_IP="10.100.0.10"

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

tmux new-session -d -s head
tmux send-keys -t head "bash ~/run_cluster.sh $VLLM_IMAGE $VLLM_HOST_IP --head /home/mars/models \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e MASTER_ADDR=$VLLM_HOST_IP \
  -e RAY_memory_monitor_refresh_ms=0" Enter

echo "Head started. Attach: tmux attach -t head"
