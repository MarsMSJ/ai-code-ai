# NFS Setup — mars-expac 4TB Drive

Shares the 4TB drive from the head node (`spark-50e0`) to all worker nodes over the **100GbE network** (`10.100.0.x`).

## Topology

| Role        | WAN IP          | 100GbE IP    |
|-------------|-----------------|--------------|
| Head        | 192.168.1.120   | 10.100.0.10   |
| Worker 1    | 192.168.1.121   | 10.100.0.11   |
| Worker 2    | 192.168.1.122   | 10.100.0.12   |
| Worker 3    | 192.168.1.123   | 10.100.0.13   |

Mount point: `/mnt/expac` on all nodes.

---

## Step 1 — Find the drive device on the head node

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
# or
fdisk -l | grep "4 TB"
```

Common paths: `/dev/sdb`, `/dev/sdc`, `/dev/nvme1n1`

---

## Step 2 — Run NFS server setup on head (192.168.1.120)

```bash
sudo NFS_DEVICE=/dev/sdb bash scripts/storage/setup-nfs-server.sh
```

Override the device if yours differs:

```bash
sudo NFS_DEVICE=/dev/nvme1n1 bash scripts/storage/setup-nfs-server.sh
```

Verify the export is active:

```bash
exportfs -v
showmount -e localhost
```

Expected output:
```
/mnt/expac  10.100.0.0/24
```

---

## Step 3 — Mount NFS on each worker node

SSH into each worker and run:

```bash
sudo bash scripts/storage/mount-nfs-client.sh
```

Verify:

```bash
df -h /mnt/expac
ls /mnt/expac
```

### Mount all workers at once from the head (SSH shortcut)

```bash
for IP in 192.168.1.{121..123}; do
    echo "==> $IP"
    ssh mars@$IP "sudo bash -s" < scripts/storage/mount-nfs-client.sh
done
```

---

## Troubleshooting

**"Connection refused" on mount** — check that `nfs-kernel-server` is running on head:
```bash
systemctl status nfs-kernel-server
```

**Slow transfer speeds** — confirm you're using 100GbE IPs (`10.100.0.x`), not WAN IPs.

**"Stale file handle" after reboot** — re-export on head and remount on worker:
```bash
# head
sudo exportfs -ra

# worker
sudo umount /mnt/expac && sudo mount -a
```

**Check what's currently exported:**
```bash
cat /etc/exports
exportfs -v
```
