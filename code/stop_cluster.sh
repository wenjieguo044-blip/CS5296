#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

for host in "${DB_NODES[@]}"; do
  echo "Stopping CockroachDB on $host"
  ssh_exec "$host" "
    pkill -9 cockroach || true
    pkill mpstat || true
    pkill sar || true
    pkill vmstat || true
  "
done

echo "Cluster stopped."
