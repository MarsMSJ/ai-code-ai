# spark-cluster setup

## Head node (192.168.1.120)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --head ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.120 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```

## Worker nodes

Run each block on the corresponding node:

### Worker 1 (192.168.1.121)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.121 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```

### Worker 2 (192.168.1.122)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.122 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```

### Worker 3 (192.168.1.123)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.123 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```

### Worker 4 (192.168.1.124)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.124 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```

### Worker 5 (192.168.1.125)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.125 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```

### Worker 6 (192.168.1.126)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.126 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```

### Worker 7 (192.168.1.127)

```bash
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
export VLLM_IMAGE=vllm-node:latest
export MN_IF_NAME=enp1s0f1np1
bash run_cluster.sh $VLLM_IMAGE 192.168.1.120 --worker ~/.cache/huggingface \
  -e VLLM_HOST_IP=192.168.1.127 \
  -e UCX_NET_DEVICES=$MN_IF_NAME \
  -e NCCL_SOCKET_IFNAME=$MN_IF_NAME \
  -e OMPI_MCA_btl_tcp_if_include=$MN_IF_NAME \
  -e GLOO_SOCKET_IFNAME=$MN_IF_NAME \
  -e TP_SOCKET_IFNAME=$MN_IF_NAME \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR=192.168.1.120 \
  -e RAY_DISABLE_METRICS=1
```
