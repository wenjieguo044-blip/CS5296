# CS5296 CockroachDB EC2 Benchmark

This repository contains the Group 21 project for benchmarking a distributed SQL database on different Amazon EC2 instance types. The project deploys a three-node CockroachDB cluster and evaluates it with sysbench OLTP workloads.

## Project Summary

The goal is to compare three EC2 instance types for a small distributed database deployment:

- `c5.large`: compute optimized, 2 vCPUs, about 4 GiB memory
- `m5.large`: general purpose, 2 vCPUs, about 8 GiB memory
- `r5.large`: memory optimized, 2 vCPUs, about 16 GiB memory

The benchmark uses:

- CockroachDB `v23.1.11`
- sysbench read-only and read-write OLTP workloads
- 3 CockroachDB nodes
- 1 separate client node
- 8 tables with 100,000 rows per table
- 4, 8, 16, and 32 client threads
- 120 seconds per run
- 3 repeated runs for each instance type

The main result is that `c5.large` achieved the best throughput and cost efficiency in the tested setup.

## Repository Layout

```text
CS5296/
├── code/
│   ├── bootstrap_ssh.sh
│   ├── cleanup_db.sh
│   ├── collect_metrics_start.sh
│   ├── collect_metrics_stop.sh
│   ├── config.sh
│   ├── deploy_cluster.sh
│   ├── install_all.sh
│   ├── parse_results.py
│   ├── prepare_db.sh
│   ├── run_benchmark.sh
│   └── stop_cluster.sh
├── results/
│   ├── results_c5_large/
│   ├── results_m5_large/
│   └── results_r5_large/
```

`code/` contains the deployment, installation, benchmark, monitoring, and parsing scripts.

`results/` contains raw logs and summary CSV files from the benchmark runs.

## Software and Hardware Dependencies

Hardware and cloud environment:

- AWS EC2 account.
- Four EC2 instances:
  - one client instance
  - three database node instances named `node1`, `node2`, and `node3`
- The three database nodes should use the same instance type in one benchmark round.
- Tested database node types: `c5.large`, `m5.large`, and `r5.large`.
- All database nodes should be in the same Availability Zone.
- The experiments were run on Amazon Linux 2023.

Software:

- CockroachDB `v23.1.11`
- sysbench `1.1.0-3ceba0b`
- `sysstat` for `mpstat` and `sar`
- `vmstat`
- `nmap-ncat` or compatible netcat
- SSH
- Python 3

The scripts in `CS5296/code/` install most required software on the EC2 instances.

## Workflow Scripts

The project workflow is built from these scripts:

- `config.sh`: stores node IP addresses, SSH settings, CockroachDB settings, workload parameters, and result directory settings.
- `bootstrap_ssh.sh`: configures SSH access from the client to the three database nodes.
- `install_all.sh`: installs CockroachDB, sysbench, and monitoring tools.
- `deploy_cluster.sh`: starts the three-node CockroachDB cluster. Use `--clean` for a fresh run.
- `prepare_db.sh`: creates the `sysbench` database and loads benchmark tables.
- `collect_metrics_start.sh`: starts CPU, memory, I/O, and network monitoring.
- `collect_metrics_stop.sh`: stops monitoring.
- `run_benchmark.sh`: runs all workload and thread combinations, collects logs, and calls the parser.
- `parse_results.py`: parses `sysbench.log` files and writes `summary.csv`.
- `stop_cluster.sh`: stops the CockroachDB cluster.
- `cleanup_db.sh`: removes old CockroachDB data when needed.

## Inputs Required to Run the Workflow

Before running the workflow, prepare these inputs:

- Public or private IP addresses for `client`, `node1`, `node2`, and `node3`.
- The EC2 SSH username, usually `ec2-user` on Amazon Linux 2023.
- The private key file (`.pem`) selected and downloaded when creating the EC2 instances.
- The SSH key path on the client instance.
- The benchmark instance tag, for example `c5_large_run1`.
- Benchmark parameters in `config.sh`, including table count, table size, thread list, workloads, runtime, and report interval.
- The target EC2 instance type for the current run: `c5.large`, `m5.large`, or `r5.large`.

Download the private key for the EC2 key pair selected when creating the instances. Copy the key to the client instance under `$HOME/.ssh/`:

```bash
scp -i /path/to/local/key.pem /path/to/local/key.pem ec2-user@CLIENT_PUBLIC_IP:~/.ssh/
```

On the client instance, set safe permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/key.pem
```

Then set `SSH_KEY` in `code/config.sh` to the key path on the client instance.

## Configuration Before Running

Edit `code/config.sh` before running the experiment:

```bash
SSH_USER="ec2-user"
SSH_KEY="/home/ec2-user/.ssh/id_ed25519"

NODE1="..."
NODE2="..."
NODE3="..."
CLIENT="..."

INSTANCE_TAG="c5_large_run1"
```

Also check the bootstrap key setting in `code/bootstrap_ssh.sh`:

```bash
BOOTSTRAP_KEY="${BOOTSTRAP_KEY:-$HOME/.ssh/ec2_gwj.pem}"
```

The `.pem` file in this line should be the private key file selected and downloaded when creating the EC2 instances. If your key has a different name or path, update `BOOTSTRAP_KEY` or set it when running the script:

```bash
BOOTSTRAP_KEY="$HOME/.ssh/your_key.pem" ./bootstrap_ssh.sh
```

Important benchmark settings are also defined in `config.sh`:

```bash
TABLES=8
TABLE_SIZE=100000
THREADS_LIST=(4 8 16 32)
WORKLOADS=("oltp_read_only" "oltp_read_write")
RUN_TIME=120
REPORT_INTERVAL=10
```

Update `INSTANCE_TAG` for each run so that results are saved in a separate directory.

## How to Prepare and Run the Experiment

First create four EC2 instances:

1. One client instance.
2. Three database node instances: `node1`, `node2`, and `node3`.

For each benchmark round, the three database nodes should use the same instance type. For example, use three `c5.large` nodes for the `c5.large` test, then repeat with three `m5.large` nodes and three `r5.large` nodes.

Run the following commands from the `CS5296/code/` directory:

```bash
cd CS5296/code
```

Set up SSH access:

```bash
./bootstrap_ssh.sh
```

Install CockroachDB, sysbench, and monitoring tools:

```bash
./install_all.sh
```

Start a clean CockroachDB cluster:

```bash
./deploy_cluster.sh --clean
```

Prepare the sysbench database:

```bash
./prepare_db.sh
```

Run the benchmark matrix and collect logs:

```bash
./run_benchmark.sh
```

Repeat the process for each EC2 instance type:

- `c5.large`
- `m5.large`
- `r5.large`

Each instance type should be tested three times.

## Expected Results After Evaluation

Each run produces a result directory under `CS5296/results/`, such as:

```text
results_c5_large/
results_m5_large/
results_r5_large/
```

Each workload and thread directory contains:

- `sysbench.log`
- per-node `mpstat.log`
- per-node `sar_net.log`
- per-node `vmstat.log`
- per-node `cockroach.log`

Each run directory also contains:

- `summary.csv`

The `summary.csv` file is generated by:

```bash
python3 parse_results.py RESULT_DIR
```

It contains the main sysbench metrics, including TPS, QPS, average latency, P95 latency, ignored errors, and reconnects.

For each workload/thread setting, expect:

- one `sysbench.log`
- one `mpstat.log` per database node
- one `sar_net.log` per database node
- one `vmstat.log` per database node
- one `cockroach.log` per database node

For each run directory, expect:

- one `summary.csv`

The `summary.csv` file should contain rows for:

- `oltp_read_only` with 4, 8, 16, and 32 threads
- `oltp_read_write` with 4, 8, 16, and 32 threads

## Expected Outputs for Validating the Report Results

The following values are the main outputs used to validate the paper's results. Small differences can occur if the experiment is rerun on new EC2 instances, but the overall trend should be similar.

Peak throughput and cost efficiency:

| Workload | Instance | Peak TPS | Cluster USD/h | TPS per USD/h |
|---|---:|---:|---:|---:|
| read-only | `c5.large` | 108.51 | 0.255 | 425.5 |
| read-only | `m5.large` | 84.96 | 0.288 | 295.0 |
| read-only | `r5.large` | 86.82 | 0.378 | 229.7 |
| read-write | `c5.large` | 70.64 | 0.255 | 277.0 |
| read-write | `m5.large` | 67.50 | 0.288 | 234.4 |
| read-write | `r5.large` | 46.78 | 0.378 | 123.7 |

System metrics at 32 threads:

| Workload | Instance | CPU % | Free Memory GiB | I/O Wait % | Cluster Network MB/s |
|---|---:|---:|---:|---:|---:|
| read-only | `c5.large` | 51.5 | 1.49 | 3.3 | 4.22 |
| read-only | `m5.large` | 44.8 | 4.82 | 3.7 | 3.39 |
| read-only | `r5.large` | 47.1 | 12.48 | 1.6 | 2.92 |
| read-write | `c5.large` | 62.5 | 1.36 | 11.6 | 5.43 |
| read-write | `m5.large` | 56.8 | 4.63 | 11.5 | 4.69 |
| read-write | `r5.large` | 61.1 | 12.23 | 7.2 | 4.53 |

The expected high-level conclusion is:

- `c5.large` should have the best throughput and cost efficiency.
- `m5.large` should be close to `c5.large` in the 32-thread read-write workload.
- `r5.large` should keep much more free memory, but it should not improve throughput for this dataset.
- Read-write workloads should show higher latency and higher I/O wait than read-only workloads.

The cost model counts only the three database nodes and excludes the client node.

## Notes

- The benchmark uses insecure CockroachDB mode for simplicity.
- The tested cluster is single-AZ, so the results do not include cross-AZ latency.
- The dataset is 800,000 rows. Larger datasets may change the memory behavior.
- EC2 prices depend on region and date.
