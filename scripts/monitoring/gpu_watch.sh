#!/usr/bin/env bash
# Live one-line-per-node GPU watch across the cluster
# Refresh: 1s

set -euo pipefail

NODE_LIST="${NODE_LIST:-10.100.0.10 10.100.0.11 10.100.0.12 10.100.0.13}"
INTERVAL="${INTERVAL:-1}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=1 -o StrictHostKeyChecking=no}"

export NODE_LIST SSH_OPTS

watch -n "$INTERVAL" -t '
for node in $NODE_LIST; do
    printf "%-15s " "$node"
    ssh $SSH_OPTS "$node" \
        "nvidia-smi --query-gpu=utilization.gpu,memory.used,power.draw,temperature.gpu,clocks.sm --format=csv,noheader" 2>/dev/null \
        || echo "unreachable"
done
'
