#!/usr/bin/env bash
# Run on each worker node before the head. Auto-detects 100GbE IP.

VLLM_IMAGE="nvcr.io/nvidia/vllm:26.03.post1-py3"
MN_IF_NAME="enp1s0f1np1"
HEAD_IP="10.100.0.10"

VLLM_HOST_IP=$(ip -4 addr show "$MN_IF_NAME" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
SESSION="w${VLLM_HOST_IP##*.}"

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

tmux new-session -d -s "$SESSION"
tmux send-keys -t "$SESSION" "bash ~/run_cluster.sh $VLLM_IMAGE $HEAD_IP --worker /home/mars/models \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e MASTER_ADDR=$HEAD_IP \
  -e RAY_memory_monitor_refresh_ms=0" Enter

echo "Worker $VLLM_HOST_IP started. Attach: tmux attach -t $SESSION"
