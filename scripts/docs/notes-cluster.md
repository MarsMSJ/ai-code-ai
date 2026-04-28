notes-cluster.md

```
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

export VLLM_IMAGE="nvcr.io/nvidia/vllm:26.03.post1-py3"
export MN_IF_NAME="enp1s0f1np1"
export VLLM_HOST_IP="10.100.0.10"
export NFS_STORE=/mnt/expac/models

tmux new -s head

bash run_cluster.sh $VLLM_IMAGE $VLLM_HOST_IP --head $NFS_STORE \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e MASTER_ADDR=$VLLM_HOST_IP \
  -e RAY_memory_monitor_refresh_ms=0
  ```

  ## Workers
  ```
  tmux new -s worker
  sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

export VLLM_IMAGE="nvcr.io/nvidia/vllm:26.03.post1-py3"
export MN_IF_NAME="enp1s0f1np1"
export VLLM_HOST_IP="10.100.0.13"
export NFS_STORE=/mnt/expac/models


bash run_cluster.sh $VLLM_IMAGE 10.100.0.10 --worker $NFS_STORE \
  -e VLLM_HOST_IP=$VLLM_HOST_IP \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e MASTER_ADDR=10.100.0.10 \
  -e RAY_memory_monitor_refresh_ms=0
  ```


  ```
  export VLLM_CONTAINER=eb5a30053cb7
  docker exec -it $VLLM_CONTAINER bash
  ```


  ```
  vllm serve /root/.cache/huggingface/MiniMaxAI/MiniMax-M2.7 \
  --served-model-name MiniMax-M2.7 \
  --tensor-parallel-size 4 \
  --max-model-len 131072 \
  --kv-cache-dtype fp8 \
  --gpu-memory-utilization 0.85 \
  --enable-prefix-caching \
  --tool-call-parser minimax_m2 \
  --reasoning-parser minimax_m2 \
  --enable-auto-tool-choice \
  --trust-remote-code \
  --host 0.0.0.0 \
  --port 8000
  ```