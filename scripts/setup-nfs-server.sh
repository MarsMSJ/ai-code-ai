#!/usr/bin/env bash
# Run on HEAD node (spark-50e0, 192.168.1.120 / 10.10.0.1)
# Mounts the 4TB mars-expac drive by label and exports it via NFS to all worker nodes.

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
DRIVE_LABEL="mars-expac"
NFS_MOUNT="${NFS_MOUNT:-/mnt/expac}"
NFS_SUBNET="10.10.0.0/24"
NFS_OPTS="rw,sync,no_subtree_check,no_root_squash"
# ──────────────────────────────────────────────────────────────────────────────

echo "==> Installing NFS server..."
apt-get update -q
apt-get install -y -q nfs-kernel-server

echo "==> Looking up device for label '$DRIVE_LABEL'..."
NFS_DEVICE=$(blkid -L "$DRIVE_LABEL" 2>/dev/null || true)
if [[ -z "$NFS_DEVICE" ]]; then
    echo "ERROR: No device found with label '$DRIVE_LABEL'."
    echo "  Check available drives and labels:"
    lsblk -o NAME,SIZE,LABEL,TYPE,MOUNTPOINT
    exit 1
fi
echo "    Found: $NFS_DEVICE"

echo "==> Creating mount point $NFS_MOUNT..."
mkdir -p "$NFS_MOUNT"

if ! grep -qs "$NFS_MOUNT" /proc/mounts; then
    echo "==> Mounting $NFS_DEVICE -> $NFS_MOUNT..."
    mount "$NFS_DEVICE" "$NFS_MOUNT"
else
    echo "    $NFS_MOUNT already mounted, skipping."
fi

if ! grep -qs "LABEL=$DRIVE_LABEL" /etc/fstab; then
    echo "==> Adding drive to /etc/fstab (by label)..."
    echo "LABEL=$DRIVE_LABEL  $NFS_MOUNT  auto  defaults,nofail  0  2" >> /etc/fstab
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
echo "  mount -t nfs 10.10.0.1:$NFS_MOUNT $NFS_MOUNT"
