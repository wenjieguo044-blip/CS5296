#!/usr/bin/env bash
set -euo pipefail

# SSH
SSH_USER="ec2-user"
SSH_KEY="/home/ec2-user/.ssh/id_ed25519"

# Nodes
NODE1="172.31.36.198"
NODE2="172.31.35.124"
NODE3="172.31.35.8"
CLIENT="172.31.39.150"

DB_NODES=("$NODE1" "$NODE2" "$NODE3")

# Instance tag
INSTANCE_TAG="r5_large_run3"

# CockroachDB
CRDB_VERSION="v23.1.11"
DB_PORT="26257"
UI_PORT="8080"
DB_NAME="sysbench"
STORE_DIR="/home/ec2-user/cockroach-data"

# Benchmark
TABLES=8
TABLE_SIZE=100000
THREADS_LIST=(4 8 16 32)
WORKLOADS=("oltp_read_only" "oltp_read_write")
RUN_TIME=120
REPORT_INTERVAL=10

# Result dir
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_DIR="${BASE_DIR}/results_${INSTANCE_TAG}"
mkdir -p "$RESULT_DIR"

# SSH helpers
ssh_exec() {
  local host="$1"
  shift
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${host}" "$@"
}

scp_from() {
  local host="$1"
  local remote_path="$2"
  local local_path="$3"
  scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${host}:${remote_path}" "$local_path"
}

join_by_comma() {
  local IFS=","
  echo "$*"
}

JOIN_ADDRS="$(join_by_comma "${DB_NODES[@]}")"
