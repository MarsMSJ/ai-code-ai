#!/bin/bash
# Live one-line-per-node GPU watch across the cluster
# Refresh: 1s

watch -n 1 -t '
for node in 10.10.0.10 10.10.0.11 10.10.0.12 10.10.0.13; do
    printf "%-15s " "$node"
    ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no $node \
        "nvidia-smi --query-gpu=utilization.gpu,memory.used,power.draw,temperature.gpu,clocks.sm --format=csv,noheader" 2>/dev/null
done
'
