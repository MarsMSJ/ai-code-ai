#!/bin/bash
# Launch a tmux session with nvidia-smi watch on all 4 Spark nodes
# Layout: 2x2 grid, one pane per node
# Detach: Ctrl-b d    |    Reattach: tmux attach -t cluster
# Switch panes: Ctrl-b arrow    |    Zoom pane: Ctrl-b z    |    Kill: Ctrl-b & y

SESSION="cluster"
NODES=("10.10.0.10" "10.10.0.11" "10.10.0.12" "10.10.0.13")

# Kill existing session if present
tmux kill-session -t "$SESSION" 2>/dev/null

# Create new session, first pane = node 0
tmux new-session -d -s "$SESSION" -x 220 -y 50 \
    "ssh -t ${NODES[0]} 'watch -n 1 nvidia-smi'"

# Split horizontally: pane 1 = node 1
tmux split-window -h -t "$SESSION" \
    "ssh -t ${NODES[1]} 'watch -n 1 nvidia-smi'"

# Select first pane, split vertically: pane 2 = node 2
tmux select-pane -t "$SESSION":0.0
tmux split-window -v -t "$SESSION" \
    "ssh -t ${NODES[2]} 'watch -n 1 nvidia-smi'"

# Select second pane (top-right), split vertically: pane 3 = node 3
tmux select-pane -t "$SESSION":0.1
tmux split-window -v -t "$SESSION" \
    "ssh -t ${NODES[3]} 'watch -n 1 nvidia-smi'"

# Even out the layout
tmux select-layout -t "$SESSION" tiled

# Attach
tmux attach -t "$SESSION"
