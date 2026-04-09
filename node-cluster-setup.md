# MiniMax-M2 on 8× NVIDIA GB10 (8 Spark Nodes) with vLLM + Ray

This document describes how to run **MiniMaxAI/MiniMax-M2** on an **8-node Spark cluster** with **1 GPU per node** using **vLLM 0.12.0** and **Ray**.

It assumes:

- Nodes:
  - `spark-50e0` (head) – IPs:
    - WAN (RJ45): `192.168.1.120`
    - 100GbE (switch): `10.10.0.1`
  - `spark-683e` – `192.168.1.121`, `10.10.0.2`
  - Worker 3 – `192.168.1.122`, `10.10.0.3`
  - Worker 4 – `192.168.1.123`, `10.10.0.4`
  - Worker 5 – `192.168.1.124`, `10.10.0.5`
  - Worker 6 – `192.168.1.125`, `10.10.0.6`
  - Worker 7 – `192.168.1.126`, `10.10.0.7`
  - Worker 8 – `192.168.1.127`, `10.10.0.8`
- Each node has **one NVIDIA GB10 GPU**.
- 100GbE interface is `enp1s0f1np1` (adjust if your interface name differs).
- You want to expose the OpenAI-compatible endpoint on
  `http://192.168.1.120:8000/v1`.

---

## 0. Preload MiniMax-M2 on All Nodes

You must make sure that **each node** has access to the MiniMax-M2 weights in a path that **containers will see**.

### Option A – Use Hugging Face cache (simple)

On **each node (120–127, on host)**:

```bash
pip install "huggingface_hub>=0.25"

python - << 'PY'
from huggingface_hub import snapshot_download

snapshot_download(
    "MiniMaxAI/MiniMax-M2",
    local_dir="/home/mars/.cache/huggingface/MiniMaxAI/MiniMax-M2",
    local_dir_use_symlinks=False,
)
PY
```

Then ensure your containers mount this cache path into `/root/.cache/huggingface`.

On **each node**, Docker will use:

```bash
-v /home/mars/.cache/huggingface:/root/.cache/huggingface
```

### Option B – Dedicated local model directory (more explicit)

On each node:

```bash
python - << 'PY'
from huggingface_hub import snapshot_download

snapshot_download(
    "MiniMaxAI/MiniMax-M2",
    local_dir="/models/MiniMax-M2",
    local_dir_use_symlinks=False,
)
PY
```

Then mount `/models/MiniMax-M2` into the containers and point vLLM at `/models/MiniMax-M2` instead of the HF ID.

---

## 1. Clean Up Old vLLM / Ray Containers

On **all nodes**, as `mars` (or root as appropriate):

```bash
docker rm -f vllm-head vllm-worker-121 vllm-worker-122 vllm-worker-123 \
             vllm-worker-124 vllm-worker-125 vllm-worker-126 vllm-worker-127 2>/dev/null || true
```

---

## 2. Start Ray Head on spark-50e0 (Node 120)

On `spark-50e0` (head):

```bash
HEAD_100G_IP=10.10.0.1
IFACE_100G=enp1s0f1np1

docker run -d --gpus all --ipc=host --network host \
  -e MASTER_ADDR=$HEAD_100G_IP \
  -e MASTER_PORT=29500 \
  -e GLOO_SOCKET_IFNAME=$IFACE_100G \
  -e NCCL_SOCKET_IFNAME=$IFACE_100G \
  -v /home/mars/models:/vllm-workspace/models \
  -v /home/mars/.cache/huggingface:/root/.cache/huggingface \
  --name spark \
  --entrypoint /bin/bash \
  vllm/vllm-openai:latest \
  -lc "ray start --head --port=6379 --block"
```

Check Ray status from the host:

```bash
docker exec -it spark ray status
```

You should see **1 active node** with **1 GPU** and no failures.

---

## 3. Start Ray Workers on the Other 7 Nodes

Run the following on each worker node, substituting the node's own `10.10.0.x` address.

```bash
HEAD_100G_IP=10.10.0.1
IFACE_100G=enp1s0f1np1

docker run -d --gpus all --ipc=host --network host \
  -e MASTER_ADDR=$HEAD_100G_IP \
  -e MASTER_PORT=29500 \
  -e GLOO_SOCKET_IFNAME=$IFACE_100G \
  -e NCCL_SOCKET_IFNAME=$IFACE_100G \
  -v /home/mars/models:/vllm-workspace/models \
  -v /home/mars/.cache/huggingface:/root/.cache/huggingface \
  --name spark \
  --entrypoint /bin/bash \
  vllm/vllm-openai:latest \
  -lc "ray start --address=$HEAD_100G_IP:6379 --block"
```

Check from the head once all workers are up:

```bash
docker exec -it spark ray status
```

You want:

* **8 active nodes**
* **8 GPUs total**
* no pending nodes / failures

---

## 4. Run vLLM Server in the Head Container

Enter the head container:

```bash
docker exec -it spark bash
cd /vllm-workspace
```

Set environment:

```bash
export SAFETENSORS_FAST_GPU=1
export VLLM_HOST_IP=10.10.0.1   # 100GbE IP of head

# Avoid CAS/xet download issues
export HF_HUB_ENABLE_XET=0
export HF_HUB_DOWNLOAD_TIMEOUT=600
export HF_HUB_DOWNLOAD_RETRY=10
```

### If using HF cache

```bash
export SAFETENSORS_FAST_GPU=1
export VLLM_HOST_IP=10.10.0.1
export HF_HUB_ENABLE_XET=0
export HF_HUB_DOWNLOAD_TIMEOUT=600
export HF_HUB_DOWNLOAD_RETRY=10

vllm serve MiniMaxAI/MiniMax-M2 \
  --trust-remote-code \
  --distributed-executor-backend ray \
  --tensor-parallel-size 8 \
  --enable-auto-tool-choice --tool-call-parser minimax_m2 \
  --reasoning-parser minimax_m2_append_think \
  --host 0.0.0.0 --port 8000
```

### If using local model directory

```bash
export SAFETENSORS_FAST_GPU=1
export VLLM_HOST_IP=10.10.0.1
export HF_HUB_ENABLE_XET=0
export HF_HUB_DOWNLOAD_TIMEOUT=600
export HF_HUB_DOWNLOAD_RETRY=10

vllm serve /vllm-workspace/models/MiniMaxAI/MiniMax-M2 \
  --trust-remote-code \
  --distributed-executor-backend ray \
  --tensor-parallel-size 8 \
  --enable-auto-tool-choice --tool-call-parser minimax_m2 \
  --reasoning-parser minimax_m2_append_think \
  --host 0.0.0.0 --port 8000
```

You should see in the logs:

* Model resolved as `MiniMaxM2ForCausalLM`
* TP world size 8, ranks spread across `10.10.0.1–10.10.0.8`
* No fatal `RuntimeError: Data processing error: CAS service error ...`

---

## 5. Verify the Server

### Inside the head node (spark-50e0)

```bash
ss -tulpn | grep 8000
curl -v http://127.0.0.1:8000/v1/models
```

You should get a JSON list of models including `"MiniMaxAI/MiniMax-M2"`.

### From your Mac

```bash
curl -v http://192.168.1.120:8000/v1/models
```

---

## 6. Test via OpenAI Python Client

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://192.168.1.120:8000/v1",
    api_key="not-needed",
)

resp = client.chat.completions.create(
    model="MiniMaxAI/MiniMax-M2",
    messages=[{"role": "user", "content": "Test from client"}],
)

print(resp.choices[0].message.content)
```

---

## 7. Notes and Gotchas

* **Model preloading must happen on every node.**
  Preloading on the **host** only helps if the containers see the **same path**. Mount `/home/mars/.cache/huggingface` into `/root/.cache/huggingface` on **every** Ray node.

* **CAS / Xet / Reqwest errors from HF**
  Setting `HF_HUB_ENABLE_XET=0` forces a simpler HTTP download path and avoids this.

* **Ray + vLLM warnings about TP > GPUs per node**
  With 1 GPU per node and TP=8, vLLM will warn that tensor parallel spans multiple nodes. That's expected; performance is fine with 100GbE interconnect.

* **Ports and addresses**
  * Ray head: `10.10.0.1:6379`
  * vLLM API: `0.0.0.0:8000` on the head → exposed as `192.168.1.120:8000` for LAN clients.
