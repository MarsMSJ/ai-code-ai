#!/usr/bin/env bash
# Run on the head node to export its SSD model directory over the 100GbE subnet.
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/home/mars/models}"
CLIENT_SUBNET="${CLIENT_SUBNET:-10.100.0.0/24}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-ro,sync,no_subtree_check}"
EXPORT_LINE="$MODEL_DIR $CLIENT_SUBNET($EXPORT_OPTIONS)"

if [[ ! -d "$MODEL_DIR" ]]; then
  echo "ERROR: Model directory does not exist: $MODEL_DIR"
  exit 1
fi

sudo apt-get update
sudo apt-get install -y nfs-kernel-server

if ! grep -Fqx "$EXPORT_LINE" /etc/exports; then
  echo "$EXPORT_LINE" | sudo tee -a /etc/exports >/dev/null
fi

sudo exportfs -ra
sudo systemctl enable --now nfs-server

echo "Exported $MODEL_DIR to $CLIENT_SUBNET"
echo "Workers can mount it with:"
echo "  sudo mount -t nfs -o ro,vers=4.2,nconnect=8 10.100.0.10:$MODEL_DIR $MODEL_DIR"
