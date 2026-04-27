#!/usr/bin/env bash
# Run on HEAD node (spark-50e0, 192.168.1.120 / 10.10.0.10)
# Mounts the mars-expac 4.5TB drive and exports it via NFS to all worker nodes.

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
NFS_MOUNT="${NFS_MOUNT:-/mnt/expac}"
NFS_SUBNET="10.10.0.0/24"
NFS_OPTS="rw,sync,no_subtree_check,no_root_squash"
# ──────────────────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    echo "Usage: sudo bash setup-nfs-server.sh <device>"
    echo "  e.g. sudo bash setup-nfs-server.sh sda1"
    echo "       sudo bash setup-nfs-server.sh sda"
    echo ""
    echo "Available disks:"
    lsblk -o NAME,SIZE,LABEL,TYPE,MOUNTPOINT | grep -v loop
    exit 1
fi

# Accept bare name (sda1) or full path (/dev/sda1)
ARG="$1"
NFS_DEVICE="/dev/${ARG#/dev/}"

if [[ ! -b "$NFS_DEVICE" ]]; then
    echo "ERROR: $NFS_DEVICE is not a block device."
    lsblk -o NAME,SIZE,LABEL,TYPE,MOUNTPOINT | grep -v loop
    exit 1
fi
echo "==> Using device: $NFS_DEVICE"

echo "==> Installing NFS server..."
apt-get update -q
apt-get install -y -q nfs-kernel-server

echo "==> Creating mount point $NFS_MOUNT..."
mkdir -p "$NFS_MOUNT"

if ! grep -qs "$NFS_MOUNT" /proc/mounts; then
    echo "==> Mounting $NFS_DEVICE -> $NFS_MOUNT..."
    mount "$NFS_DEVICE" "$NFS_MOUNT"
else
    echo "    $NFS_MOUNT already mounted, skipping."
fi

if ! grep -qs "$NFS_MOUNT" /etc/fstab; then
    echo "==> Adding drive to /etc/fstab..."
    UUID=$(blkid -s UUID -o value "$NFS_DEVICE")
    echo "UUID=$UUID  $NFS_MOUNT  auto  defaults,nofail  0  2" >> /etc/fstab
fi

echo "==> Configuring NFS export..."
EXPORT_LINE="$NFS_MOUNT  $NFS_SUBNET($NFS_OPTS)"
if ! grep -qF "$NFS_MOUNT" /etc/exports; then
    echo "$EXPORT_LINE" >> /etc/exports
else
    sed -i "s|^$NFS_MOUNT.*|$EXPORT_LINE|" /etc/exports
fi

echo "==> Starting / reloading NFS..."
systemctl enable --now nfs-kernel-server
exportfs -ra
exportfs -v

echo ""
echo "Done. NFS export:"
echo "  $NFS_MOUNT -> $NFS_SUBNET"
echo ""
echo "Workers should mount with:"
echo "  mount -t nfs 10.10.0.10:$NFS_MOUNT $NFS_MOUNT"
