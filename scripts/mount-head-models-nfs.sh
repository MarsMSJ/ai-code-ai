#!/usr/bin/env bash
# Run on each worker node to mount the head node's SSD model directory.
set -euo pipefail

HEAD_IP="${HEAD_IP:-10.100.0.10}"
MODEL_DIR="${MODEL_DIR:-/home/mars/models}"
MOUNT_OPTIONS="${MOUNT_OPTIONS:-ro,vers=4.2,nconnect=8}"

sudo apt-get update
sudo apt-get install -y nfs-common
sudo mkdir -p "$MODEL_DIR"

if mountpoint -q "$MODEL_DIR"; then
  echo "$MODEL_DIR is already mounted."
else
  sudo mount -t nfs -o "$MOUNT_OPTIONS" "$HEAD_IP:$MODEL_DIR" "$MODEL_DIR"
fi

echo "Mounted $HEAD_IP:$MODEL_DIR at $MODEL_DIR"
