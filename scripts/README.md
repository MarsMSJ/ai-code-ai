# Scripts

Helper scripts are grouped by the job they perform:

- `benchmarks/` - model benchmark drivers and endpoint tests.
- `cluster/` - Ray and vLLM startup scripts for Docker and venv deployments.
- `storage/` - NFS setup, model sharing, and model sync helpers.
- `monitoring/` - GPU and cluster watch/logging tools.
- `docs/` - runbooks and notes for cluster and storage setup.

Common entry points:

```bash
# Start the Docker Ray head node.
sudo bash scripts/cluster/start-ray-head.sh

# Start vLLM on the head node.
bash scripts/cluster/start-vllm.sh

# Run the portable agentic benchmark.
bash scripts/benchmarks/agentic_bench_universal.sh MiniMax-M2.7 http://192.168.1.120:8000/v1
```

Some upstream vLLM Docker images do not include the `ray` CLI required by
`run_cluster.sh`. Build a local Ray-enabled variant first:

```bash
bash scripts/cluster/build-vllm-ray-image.sh
sudo VLLM_IMAGE=vllm-ray:26.04-py3 bash scripts/cluster/start-ray-head.sh
```
