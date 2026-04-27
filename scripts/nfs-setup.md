# NFS Setup — mars-expac 4TB Drive

Shares the 4TB drive from the head node (`spark-50e0`) to all worker nodes over the **100GbE network** (`10.10.0.x`).

## Topology

| Role        | WAN IP          | 100GbE IP    |
|-------------|-----------------|--------------|
| Head        | 192.168.1.120   | 10.10.0.1    |
| Worker 1    | 192.168.1.121   | 10.10.0.2    |
| Worker 2    | 192.168.1.122   | 10.10.0.3    |
| Worker 3    | 192.168.1.123   | 10.10.0.4    |
| Worker 4    | 192.168.1.124   | 10.10.0.5    |
| Worker 5    | 192.168.1.125   | 10.10.0.6    |
| Worker 6    | 192.168.1.126   | 10.10.0.7    |
| Worker 7    | 192.168.1.127   | 10.10.0.8    |

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
sudo NFS_DEVICE=/dev/sdb bash scripts/setup-nfs-server.sh
```

Override the device if yours differs:

```bash
sudo NFS_DEVICE=/dev/nvme1n1 bash scripts/setup-nfs-server.sh
```

Verify the export is active:

```bash
exportfs -v
showmount -e localhost
```

Expected output:
```
/mnt/expac  10.10.0.0/24
```

---

## Step 3 — Mount NFS on each worker node

SSH into each worker and run:

```bash
sudo bash scripts/mount-nfs-client.sh
```

Verify:

```bash
df -h /mnt/expac
ls /mnt/expac
```

### Mount all workers at once from the head (SSH shortcut)

```bash
for IP in 10.10.0.{2..8}; do
    echo "==> $IP"
    ssh mars@$IP "sudo bash -s" < scripts/mount-nfs-client.sh
done
```

---

## Troubleshooting

**"Connection refused" on mount** — check that `nfs-kernel-server` is running on head:
```bash
systemctl status nfs-kernel-server
```

**Slow transfer speeds** — confirm you're using 100GbE IPs (`10.10.0.x`), not WAN IPs.

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
