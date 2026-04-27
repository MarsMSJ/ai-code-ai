#!/usr/bin/env bash
# Run on each worker to copy the head node's model directory to local SSD.
set -euo pipefail

HEAD_SSH="${HEAD_SSH:-mars@10.100.0.10}"
MODEL_RELATIVE_PATH="${MODEL_RELATIVE_PATH:-MiniMaxAI/MiniMax-M2.7}"
MODELS_ROOT="${MODELS_ROOT:-/home/mars/models}"
SOURCE="$HEAD_SSH:$MODELS_ROOT/$MODEL_RELATIVE_PATH/"
DEST="$MODELS_ROOT/$MODEL_RELATIVE_PATH/"

mkdir -p "$DEST"

rsync -aH --info=progress2 --partial --inplace "$SOURCE" "$DEST"

echo "Synced $SOURCE to $DEST"
