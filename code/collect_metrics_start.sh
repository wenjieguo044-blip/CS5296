#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

for host in "${DB_NODES[@]}"; do
  echo "Starting metrics on $host"
  ssh_exec "$host" "
    METRIC_DIR=\$HOME/metrics
    mkdir -p \$METRIC_DIR
    pkill mpstat || true
    pkill sar || true
    pkill vmstat || true
    nohup mpstat 1 > \$METRIC_DIR/mpstat.log 2>&1 &
    nohup sar -n DEV 1 > \$METRIC_DIR/sar_net.log 2>&1 &
    nohup vmstat 1 > \$METRIC_DIR/vmstat.log 2>&1 &
  "
done
