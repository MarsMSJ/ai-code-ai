#!/usr/bin/env bash
# Launch a tmux session with nvitop on all Spark nodes.
# Layout: 2x2 grid, one pane per node
# Detach: Ctrl-b d    |    Reattach: tmux attach -t cluster
# Switch panes: Ctrl-b arrow    |    Zoom pane: Ctrl-b z    |    Kill: Ctrl-b & y

set -euo pipefail

SESSION="${SESSION:-cluster}"
NODE_LIST="${NODE_LIST:-10.100.0.10 10.100.0.11 10.100.0.12 10.100.0.13}"
SSH_OPTS="${SSH_OPTS:--o ConnectTimeout=2 -o StrictHostKeyChecking=no}"
REMOTE_MONITOR='if command -v nvitop >/dev/null 2>&1; then exec nvitop; else exec watch -n 1 nvidia-smi; fi'

read -r -a NODES <<< "$NODE_LIST"

if [[ "${#NODES[@]}" -eq 0 ]]; then
    echo "ERROR: NODE_LIST is empty."
    exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "ERROR: tmux is required for cluster_watch.sh."
    exit 1
fi

# Kill existing session if present
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Create new session, first pane = node 0.
tmux new-session -d -s "$SESSION" -x 220 -y 50 \
    "ssh -t $SSH_OPTS ${NODES[0]} '$REMOTE_MONITOR'"

for i in "${!NODES[@]}"; do
    if [[ "$i" -eq 0 ]]; then
        continue
    fi

    tmux split-window -t "$SESSION" \
        "ssh -t $SSH_OPTS ${NODES[$i]} '$REMOTE_MONITOR'"
    tmux select-layout -t "$SESSION" tiled >/dev/null
done

# Even out the layout
tmux select-layout -t "$SESSION" tiled

# Attach
tmux attach -t "$SESSION"
