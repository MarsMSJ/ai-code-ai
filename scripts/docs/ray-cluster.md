# Ray Cluster Setup — MiniMax-M2 on 8× GB10 Spark Nodes

Runs `MiniMaxAI/MiniMax-M2` using vLLM with Ray for tensor parallelism across all 8 nodes.

Two modes — pick one:

| Mode | Scripts | When to use |
|------|---------|-------------|
| **Docker** | `scripts/cluster/start-ray-head.sh`, `scripts/cluster/start-ray-worker.sh`, `scripts/cluster/start-vllm.sh` | Clean container isolation |
| **venv** | `scripts/cluster/start-ray-head-venv.sh`, `scripts/cluster/start-ray-worker-venv.sh`, `scripts/cluster/start-vllm-venv.sh` | vLLM installed via `uv pip install vllm` in `.venv-tq` |

- 100GbE interface: `enp1s0f1np1`
- API endpoint: `http://192.168.1.120:8000/v1`

---

## Mode A — Docker

### 1. Head node (192.168.1.120)

If your selected Docker image does not include the `ray` CLI, build a local
variant first:

```bash
BASE_IMAGE=nvcr.io/nvidia/vllm:26.04-py3 \
OUTPUT_IMAGE=vllm-ray:26.04-py3 \
  bash scripts/cluster/build-vllm-ray-image.sh
```

```bash
sudo VLLM_IMAGE=vllm-ray:26.04-py3 bash scripts/cluster/start-ray-head.sh
```

Confirm it's running:

```bash
docker exec -it spark ray status
# Expect: 1 active node, 1 GPU
```

### 2. Each worker node (192.168.1.121–127)

SSH into each and run:

```bash
sudo bash scripts/cluster/start-ray-worker.sh
```

Or from the head in one shot:

```bash
for IP in 192.168.1.{121..123}; do
    echo "==> Starting worker on $IP"
    ssh mars@$IP "sudo VLLM_IMAGE=vllm/vllm-openai:latest bash -s" \
        < scripts/cluster/start-ray-worker.sh &
done
wait
echo "All workers launched."
```

### 3. Verify all 8 nodes (from head)

```bash
docker exec -it spark ray status
```

### 4. Start vLLM server (from head)

```bash
bash scripts/cluster/start-vllm.sh
```

### Teardown

```bash
for IP in 192.168.1.{120..123}; do
    ssh mars@$IP "docker rm -f spark" &
done
wait
```

---

## Mode B — Python venv (`.venv-tq`)

Install vLLM once (or put the venv on NFS so all nodes share it):

```bash
uv venv --python 3.12 .venv-tq
source .venv-tq/bin/activate
uv pip install vllm
```

If you put the venv on NFS, set `VENV_PATH=/mnt/expac/venv-tq` in each command below.

### 1. Head node (192.168.1.120)

```bash
sudo bash scripts/cluster/start-ray-head-venv.sh
```

Confirm:

```bash
/home/mars/.venv-tq/bin/ray status
# Expect: 1 active node, 1 GPU
```

### 2. Each worker node (192.168.1.121–127)

```bash
sudo bash scripts/cluster/start-ray-worker-venv.sh
```

Or from the head in one shot:

```bash
for IP in 192.168.1.{121..123}; do
    echo "==> $IP"
    ssh mars@$IP "sudo bash -s" < scripts/cluster/start-ray-worker-venv.sh &
done
wait
echo "All workers joined."
```

### 3. Verify all 8 nodes (from head)

```bash
/home/mars/.venv-tq/bin/ray status
```

You want:
- **4 active nodes**
- **4 GPUs total**
- 0 pending / 0 failed

### 4. Start vLLM server (from head)

```bash
bash scripts/cluster/start-vllm-venv.sh
```

### Teardown

```bash
for IP in 192.168.1.{120..123}; do
    ssh mars@$IP "/home/mars/.venv-tq/bin/ray stop --force" &
done
wait
```

---

## Environment Variables Reference

| Variable              | Default                               | Applies to  | Purpose                             |
|-----------------------|---------------------------------------|-------------|-------------------------------------|
| `VLLM_IMAGE`          | `vllm/vllm-openai:latest`             | Docker only | Docker image to use                 |
| `VENV_PATH`           | `/home/mars/.venv-tq`                 | venv only   | Path to the Python venv             |
| `HF_CACHE`            | `/home/mars/.cache/huggingface`       | Docker only | HF weights cache on host            |
| `MODELS_DIR`          | `/home/mars/models`                   | Docker only | Local model directory on host       |
| `LOCAL_MODEL_PATH`    | `/mnt/expac/models/MiniMaxAI/MiniMax-M2` | venv only | Local model weights path           |
| `NFS_MOUNT`           | `/mnt/expac`                          | Both        | NFS share mount point               |
| `IFACE_100G`          | `enp1s0f1np1`                         | Both        | 100GbE interface (auto-detected)    |

---

## Verifying the API

From the head node:

```bash
curl http://127.0.0.1:8000/v1/models
```

From your Mac:

```bash
curl http://192.168.1.120:8000/v1/models
```

Expected response includes `"MiniMaxAI/MiniMax-M2"`.

---

## Quick Python test

```python
from openai import OpenAI

client = OpenAI(base_url="http://192.168.1.120:8000/v1", api_key="not-needed")
resp = client.chat.completions.create(
    model="MiniMaxAI/MiniMax-M2",
    messages=[{"role": "user", "content": "Hello"}],
)
print(resp.choices[0].message.content)
```

---

## Gotchas

- **Model weights must be accessible from every node** — either via NFS (`/mnt/expac`) or pre-downloaded to each node's local disk. Mount NFS first (see `scripts/docs/nfs-setup.md`).
- **CAS/Xet download errors from HF** — `HF_HUB_ENABLE_XET=0` forces simple HTTP and avoids this.
- **TP > GPUs-per-node warning from vLLM** — expected; 1 GPU per node with TP=8 spans nodes. Fine on 100GbE.
- **`ray: command not found` in Docker** — the selected vLLM image does not include Ray. Build a local Ray-enabled image with `scripts/cluster/build-vllm-ray-image.sh` and use it via `VLLM_IMAGE`.
- **Ray port 6379 must be open** between all nodes on the 10.100.0.x network.
