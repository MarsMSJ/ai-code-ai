Yeah, I believe you that you preloaded the model — but the stack trace is showing **Ray workers on the other nodes** still trying to download shards from Hugging Face:

* The failing process is on `ip=10.10.0.2` / `10.10.0.3` / `10.10.0.4`
* Inside *their* containers, `/root/.cache/huggingface` is **not** the same as the cache you warmed on the head (unless you explicitly mounted it there too).
* So from their POV, the model isn’t cached, and they hit HF → CAS/xet → boom.

Preloading only “counts” where vLLM is actually running, and inside Docker that means:

* Either you mount the cache into **every** container on **every** node
* Or you mount a **fully downloaded local copy** of the repo and point vLLM at that.

---

Below is what you asked for: a **single self-contained markdown doc** that captures the steps that *worked* for the Ray cluster + vLLM + MiniMax-M2 setup, with the fixes to avoid HF download issues.

You can save this as e.g. `spark-minimax-m2-ray-vllm-4node.md`.

---

````markdown
# MiniMax-M2 on 4× NVIDIA GB10 (4 Spark Nodes) with vLLM + Ray

This document describes how to run **MiniMaxAI/MiniMax-M2** on a **4-node Spark cluster** with **1 GPU per node** using **vLLM 0.12.0** and **Ray**.

It assumes:

- Nodes:
  - `spark-50e0` (head) – IPs:  
    - WAN (RJ45): `192.168.1.120`  
    - 100GbE (switch): `10.10.0.1`  
  - `spark-683e` – `192.168.1.121`, `10.10.0.2`
  - `spark-XXXX` – `192.168.1.122`, `10.10.0.3`
  - `spark-YYYY` – `192.168.1.123`, `10.10.0.4`
- Each node has **one NVIDIA GB10 GPU**.
- 100GbE interface is `enp1s0f1np1` (adjust if your interface name differs).
- You want to expose the OpenAI-compatible endpoint on  
  `http://192.168.1.120:8000/v1`.

---

## 0. Preload MiniMax-M2 on All Nodes

You must make sure that **each node** has access to the MiniMax-M2 weights in a path that **containers will see**.

### Option A – Use Hugging Face cache (simple)

On **each node (120–123, on host)**:

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
````

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
docker rm -f vllm-head vllm-worker-121 vllm-worker-122 vllm-worker-123 2>/dev/null || true
```

---

## 2. Start Ray Head on spark-50e0 (Node 120)

On `spark-50e0` (head), choose:

```bash
HEAD_100G_IP=10.10.0.1          # 100GbE
IFACE_100G=enp1s0f1np1          # 100GbE interface name
```

Start the head container:

```bash
HEAD_100G_IP=10.10.0.1          # 100GbE
IFACE_100G=enp1s0f1np1          # 100GbE interface name

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

## 3. Start Ray Workers on the Other Nodes

Repeat on each worker node with its own `10.10.0.x` address.

## On Worker Nodes

```bash
HEAD_100G_IP=10.0.0.1
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
docker stop spark-a61c 2>/dev/null || true \
docker rm spark-a61c
Now check from the head again:

```bash
docker exec -it vllm-head ray status
```

You want:

* **4 active nodes**
* **4 GPUs total**
* no pending nodes / failures

---

## 4. Run vLLM Server in the Head Container

Enter the head container:

```bash
docker exec -it vllm-head bash
cd /vllm-workspace
```

Set environment:

```bash
export SAFETENSORS_FAST_GPU=1
export VLLM_HOST_IP=10.10.0.1   # 100GbE IP of head

# Optional but recommended to avoid CAS/xet download issues
export HF_HUB_ENABLE_XET=0
export HF_HUB_DOWNLOAD_TIMEOUT=600
export HF_HUB_DOWNLOAD_RETRY=10
```

Choose tensor parallel size:

```bash
TP=4    # 4 GPUs total (1 per node)
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
  --tensor-parallel-size "$TP" \
  --enable-auto-tool-choice --tool-call-parser minimax_m2 \
  --reasoning-parser minimax_m2_append_think \
  --host 0.0.0.0 --port 8000
```

### If using local model directory

If you mounted `/models/MiniMax-M2` on all nodes:

```bash
export SAFETENSORS_FAST_GPU=1
export VLLM_HOST_IP=10.10.0.1
export HF_HUB_ENABLE_XET=0
export HF_HUB_DOWNLOAD_TIMEOUT=600
export HF_HUB_DOWNLOAD_RETRY=10

vllm serve /vllm-workspace/models/MiniMaxAI/MiniMax-M2 \
  --trust-remote-code \
  --distributed-executor-backend ray \
  --tensor-parallel-size 4 \
  --enable-auto-tool-choice --tool-call-parser minimax_m2 \
  --reasoning-parser minimax_m2_append_think \
  --host 0.0.0.0 --port 8000
```

You should see in the logs:

* Model resolved as `MiniMaxM2ForCausalLM`
* TP world size 4, ranks spread across `10.10.0.1–10.10.0.4`
* No fatal `RuntimeError: Data processing error: CAS service error ...`

---

## 5. Verify the Server

### Inside the head node (spark-50e0)

From the host:

```bash
ss -tulpn | grep 8000
curl -v http://127.0.0.1:8000/v1/models
```

You should get a JSON list of models including `"MiniMaxAI/MiniMax-M2"` (or the path you served).

### From your Mac (192.168.1.125 → 192.168.1.120)

```bash
curl -v http://192.168.1.120:8000/v1/models
```

This checks that:

* RJ45 interface `192.168.1.120` is reachable
* Docker is listening on `0.0.0.0:8000` on the host

---

## 6. Test via OpenAI Python Client

In your `openai` environment on the Mac:

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

If everything is wired correctly, you should see a normal chat response.

---

## 7. Notes and Gotchas

* **“But I preloaded the models!”**
  Preloading on the **host** only helps if the containers can see the **same path**. That’s why we mount `/home/mars/.cache/huggingface` into `/root/.cache/huggingface` on **every** Ray node, not just the head.

* **CAS / Xet / Reqwest errors from HF**
  These usually come from `huggingface_hub`’s xet backend. Setting:

  ```bash
  export HF_HUB_ENABLE_XET=0
  ```

  forces a simpler HTTP download path and avoids that specific error.

* **Ray + vLLM warnings about TP > GPUs per node**
  With 1 GPU per node and TP=4, vLLM will warn that tensor parallel spans multiple nodes. That’s expected in this setup; performance is still fine with good interconnect (your 100GbE).

* **Ports and addresses**

  * Ray head: `10.10.0.1:6379`
  * vLLM API: `0.0.0.0:8000` on the head → exposed as `192.168.1.120:8000` for LAN clients.

---

End of document.

```

If you want, I can trim this down into a shorter “ops runbook” version, but this one captures all the pieces that actually matter for your current setup, including why the HF errors happened even though you’d already pulled the model.
::contentReference[oaicite:0]{index=0}
```
