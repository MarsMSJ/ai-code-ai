#!/usr/bin/env bash
# Run on HEAD node (192.168.1.120).
# SSHes into each worker and mounts the NFS share from the head.

set -euo pipefail

HEAD_NFS_IP="192.168.1.120"
NFS_EXPORT="/mnt/expac"
LOCAL_MOUNT="/mnt/expac"
WORKERS=(
    192.168.1.121
    192.168.1.122
    192.168.1.123
)

MOUNT_CMD="
    apt-get install -y -q nfs-common
    mkdir -p $LOCAL_MOUNT
    if ! grep -qs $LOCAL_MOUNT /proc/mounts; then
        mount -t nfs -o rsize=1048576,wsize=1048576,hard,intr $HEAD_NFS_IP:$NFS_EXPORT $LOCAL_MOUNT
    fi
    if ! grep -qF '$HEAD_NFS_IP:$NFS_EXPORT' /etc/fstab; then
        echo '$HEAD_NFS_IP:$NFS_EXPORT  $LOCAL_MOUNT  nfs  defaults,_netdev,nofail,rsize=1048576,wsize=1048576,hard,intr  0  0' >> /etc/fstab
    fi
    df -h $LOCAL_MOUNT
"

for IP in "${WORKERS[@]}"; do
    echo "==> Mounting NFS on $IP..."
    ssh -o StrictHostKeyChecking=no mars@$IP "sudo bash -c '$MOUNT_CMD'" && \
        echo "    OK: $IP" || \
        echo "    FAILED: $IP"
done

echo ""
echo "Done. Clone the repo on the share (run once):"
echo "  cd $LOCAL_MOUNT && git clone https://github.com/MarsMSJ/ai-code-ai.git"
