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
sudo mount -o remount,size=120G /dev/shm

ray stop --force 2>/dev/null || true
sleep 2

export GLOO_SOCKET_IFNAME="$IFACE_100G"
export NCCL_SOCKET_IFNAME="$IFACE_100G"
export UCX_NET_DEVICES="$IFACE_100G"

ray start \
    --address="$HEAD_100G_IP:$RAY_PORT" \
    --node-ip-address="$WORKER_100G_IP" \
    --object-manager-port=8076 \
    --node-manager-port=8077 \
    --object-store-memory=115000000000
