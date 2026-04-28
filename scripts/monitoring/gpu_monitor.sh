#!/usr/bin/env bash
# Log GPU power, util, mem, temp, clocks across all 4 Spark nodes to CSV
# Run in a separate pane during benchmarks

set -euo pipefail

NODE_LIST="${NODE_LIST:-10.100.0.10 10.100.0.11 10.100.0.12 10.100.0.13}"
INTERVAL="${INTERVAL:-0.5}"
LOG="${LOG:-/tmp/gpu_tdp_$(date +%Y%m%d_%H%M%S).csv}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=2 -o StrictHostKeyChecking=no}"

read -r -a NODES <<< "$NODE_LIST"

echo "timestamp,node,gpu_util,mem_used_mb,mem_total_mb,power_w,power_limit_w,temp_c,sm_clock_mhz" > "$LOG"
echo "Logging to $LOG"
echo "Press Ctrl-C to stop"

trap "echo; echo 'Stopped. Log: $LOG'; exit 0" INT

while true; do
    TS=$(date +%s.%N)
    for node in "${NODES[@]}"; do
        DATA=$(ssh $SSH_OPTS "$node" \
            "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,power.draw,power.limit,temperature.gpu,clocks.sm --format=csv,noheader,nounits" 2>/dev/null || true)
        if [ -n "$DATA" ]; then
            echo "$TS,$node,$DATA" | tr -d ' ' >> "$LOG"
        fi
    done
    sleep "$INTERVAL"
done
