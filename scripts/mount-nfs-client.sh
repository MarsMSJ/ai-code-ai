#!/usr/bin/env bash
# Run on each WORKER node (192.168.1.121–127 / 10.10.0.2–8)
# Mounts the NFS share exported by the head node.

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
HEAD_NFS_IP="${HEAD_NFS_IP:-10.10.0.10}"
NFS_EXPORT="${NFS_EXPORT:-/mnt/expac}"
LOCAL_MOUNT="${LOCAL_MOUNT:-/mnt/expac}"
NFS_MOUNT_OPTS="nfs  defaults,_netdev,nofail,rsize=1048576,wsize=1048576,hard,intr  0  0"
# ──────────────────────────────────────────────────────────────────────────────

echo "==> Installing NFS client..."
apt-get update -q
apt-get install -y -q nfs-common

echo "==> Creating local mount point $LOCAL_MOUNT..."
mkdir -p "$LOCAL_MOUNT"

if ! grep -qs "$LOCAL_MOUNT" /proc/mounts; then
    echo "==> Mounting $HEAD_NFS_IP:$NFS_EXPORT -> $LOCAL_MOUNT..."
    mount -t nfs -o rsize=1048576,wsize=1048576,hard,intr \
        "$HEAD_NFS_IP:$NFS_EXPORT" "$LOCAL_MOUNT"
else
    echo "    $LOCAL_MOUNT already mounted, skipping."
fi

FSTAB_ENTRY="$HEAD_NFS_IP:$NFS_EXPORT  $LOCAL_MOUNT  $NFS_MOUNT_OPTS"
if ! grep -qF "$HEAD_NFS_IP:$NFS_EXPORT" /etc/fstab; then
    echo "==> Adding NFS entry to /etc/fstab..."
    echo "$FSTAB_ENTRY" >> /etc/fstab
else
    echo "    fstab entry already present, skipping."
fi

echo ""
echo "Done. Verifying mount:"
df -h "$LOCAL_MOUNT"
