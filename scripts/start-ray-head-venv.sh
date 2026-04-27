#!/usr/bin/env bash
# Run on HEAD node: spark-50e0 (192.168.1.120 / 10.100.0.10)
# Requires .venv-tq already activated: source ~/.venv-tq/bin/activate

set -euo pipefail

HEAD_100G_IP="10.100.0.10"
IFACE_100G="enp1s0f1np1"
RAY_PORT=6379

sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

ray stop --force 2>/dev/null || true
sleep 2

export GLOO_SOCKET_IFNAME="$IFACE_100G"
export NCCL_SOCKET_IFNAME="$IFACE_100G"
export UCX_NET_DEVICES="$IFACE_100G"

ray start \
    --head \
    --port="$RAY_PORT" \
    --dashboard-port=8265 \
    --node-ip-address="$HEAD_100G_IP" \
    --object-manager-port=8076 \
    --node-manager-port=8077 \
    --ray-client-server-port=10001 \
    --object-store-memory=10000000000

ray status
