#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

MODE="restart"
if [[ "${1:-}" == "--clean" ]]; then
  MODE="clean"
fi

echo "Deploy mode: ${MODE}"

stop_node() {
  local host="$1"
  echo "  -> stopping on $host"
  ssh_exec "$host" "
    pkill -9 cockroach || true
    sleep 3
  "
}

clean_node() {
  local host="$1"
  echo "  -> cleaning data on $host"
  ssh_exec "$host" "
    sudo rm -rf ${STORE_DIR} || true
    mkdir -p ${STORE_DIR}
    echo cleaned
  "
}

start_node() {
  local host="$1"
  echo "  -> starting on $host"
  ssh_exec "$host" "
    nohup cockroach start \
      --insecure \
      --advertise-addr=${host} \
      --listen-addr=${host}:${DB_PORT} \
      --http-addr=${host}:${UI_PORT} \
      --join=${JOIN_ADDRS} \
      --store=${STORE_DIR} \
      --cache=25% \
      --max-sql-memory=25% \
      > cockroach.log 2>&1 &
    sleep 5
    ss -lntp | grep ${DB_PORT} || true
  "
}

wait_for_sql() {
  local host="$1"
  echo "Waiting for SQL service on $host..."
  for i in {1..20}; do
    if ssh_exec "$CLIENT" "nc -z ${host} ${DB_PORT}" >/dev/null 2>&1; then
      echo "  -> ${host}:${DB_PORT} is reachable"
      return 0
    fi
    sleep 2
  done
  echo "ERROR: ${host}:${DB_PORT} did not become reachable in time"
  return 1
}

check_cluster_status() {
  echo "Checking cluster status..."
  for i in {1..15}; do
    if ssh_exec "$NODE1" "cockroach node status --insecure --host=${NODE1}:${DB_PORT}" >/tmp/crdb_status.out 2>/tmp/crdb_status.err; then
      cat /tmp/crdb_status.out
      return 0
    fi
    echo "  -> cluster not ready yet, retrying (${i}/15)"
    sleep 2
  done

  echo "ERROR: cluster status check failed"
  echo "---- STDOUT ----"
  cat /tmp/crdb_status.out || true
  echo "---- STDERR ----"
  cat /tmp/crdb_status.err || true
  return 1
}

echo "Stopping existing CockroachDB processes..."
for host in "${DB_NODES[@]}"; do
  stop_node "$host"
done

if [[ "$MODE" == "clean" ]]; then
  echo "Cleaning data directories..."
  for host in "${DB_NODES[@]}"; do
    clean_node "$host"
  done
fi

echo "Starting CockroachDB on all DB nodes..."
for host in "${DB_NODES[@]}"; do
  start_node "$host"
done

echo "Waiting for nodes to accept SQL connections..."
for host in "${DB_NODES[@]}"; do
  wait_for_sql "$host"
done

if [[ "$MODE" == "clean" ]]; then
  echo "Initializing new cluster..."
  ssh_exec "$NODE1" "
    cockroach init --insecure --host=${NODE1}:${DB_PORT}
  "
else
  echo "Restart mode: skipping cluster init"
fi

check_cluster_status

echo "Deployment finished successfully."
