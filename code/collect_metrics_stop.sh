#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

for host in "${DB_NODES[@]}"; do
  echo "Stopping metrics on $host"
  ssh_exec "$host" "
    pkill mpstat || true
    pkill sar || true
    pkill vmstat || true
  "
done
