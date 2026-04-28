#!/usr/bin/env bash
# Run on each worker to copy the head node's model directory to local SSD.
set -euo pipefail

HEAD_SSH="${HEAD_SSH:-mars@10.100.0.10}"
MODEL_RELATIVE_PATH="${MODEL_RELATIVE_PATH:-MiniMaxAI/MiniMax-M2.7}"
MODELS_ROOT="${MODELS_ROOT:-/home/mars/models}"
SOURCE="$HEAD_SSH:$MODELS_ROOT/$MODEL_RELATIVE_PATH/"
DEST="$MODELS_ROOT/$MODEL_RELATIVE_PATH/"

if mountpoint -q "$MODELS_ROOT"; then
  echo "ERROR: $MODELS_ROOT is a mounted filesystem, not the worker's local SSD path."
  echo "Unmount it first if you want vLLM to load from local SSD:"
  echo "  sudo umount $MODELS_ROOT"
  exit 1
fi

sudo mkdir -p "$DEST"
sudo chown -R "$(id -u):$(id -g)" "$MODELS_ROOT"

rsync -aH --info=progress2 --partial --inplace "$SOURCE" "$DEST"

echo "Synced $SOURCE to $DEST"
