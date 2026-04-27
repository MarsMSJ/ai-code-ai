#!/usr/bin/env bash
# Run on HEAD node (spark-50e0, 192.168.1.120 / 10.10.0.1)
# Mounts the 4TB mars-expac drive and exports it via NFS to all worker nodes.

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
NFS_DEVICE="${NFS_DEVICE:-/dev/sdb}"   # override: NFS_DEVICE=/dev/nvme1n1 ./setup-nfs-server.sh
NFS_MOUNT="${NFS_MOUNT:-/mnt/expac}"
NFS_SUBNET="10.10.0.0/24"             # 100GbE network only
NFS_OPTS="rw,sync,no_subtree_check,no_root_squash"
# ──────────────────────────────────────────────────────────────────────────────

echo "==> Installing NFS server..."
apt-get update -q
apt-get install -y -q nfs-kernel-server

echo "==> Checking device $NFS_DEVICE..."
if ! lsblk "$NFS_DEVICE" &>/dev/null; then
    echo "ERROR: device $NFS_DEVICE not found. Set NFS_DEVICE= to the correct block device."
    lsblk
    exit 1
fi

echo "==> Creating mount point $NFS_MOUNT..."
mkdir -p "$NFS_MOUNT"

if ! grep -qs "$NFS_MOUNT" /proc/mounts; then
    echo "==> Mounting $NFS_DEVICE -> $NFS_MOUNT..."
    mount "$NFS_DEVICE" "$NFS_MOUNT"
else
    echo "    $NFS_MOUNT already mounted, skipping."
fi

if ! grep -qs "$NFS_DEVICE" /etc/fstab; then
    echo "==> Adding $NFS_DEVICE to /etc/fstab..."
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
echo "  mount -t nfs 10.10.0.1:$NFS_MOUNT $NFS_MOUNT"
