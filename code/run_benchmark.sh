#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

mkdir -p "$RESULT_DIR"

echo "Checking sysbench availability on client..."
ssh_exec "$CLIENT" "
  command -v sysbench >/dev/null 2>&1 && sysbench --version
"

echo "Running workloads: ${WORKLOADS[*]}"
echo "Thread settings: ${THREADS_LIST[*]}"
echo "Results directory: ${RESULT_DIR}"

for workload in "${WORKLOADS[@]}"; do
  for threads in "${THREADS_LIST[@]}"; do
    RUN_TAG="${workload}_t${threads}"
    RUN_DIR="${RESULT_DIR}/${RUN_TAG}"
    mkdir -p "$RUN_DIR"

    echo "======================================"
    echo "Running: workload=${workload}, threads=${threads}"
    echo "Results: $RUN_DIR"
    echo "======================================"

    ./collect_metrics_start.sh

    ssh_exec "$CLIENT" "
      sysbench \
        --db-driver=pgsql \
        --db-ps-mode=disable \
        ${workload} \
        --pgsql-host=${NODE1} \
        --pgsql-port=${DB_PORT} \
        --pgsql-user=root \
        --pgsql-db=${DB_NAME} \
        --tables=${TABLES} \
        --table-size=${TABLE_SIZE} \
        --threads=${threads} \
        --time=${RUN_TIME} \
        --report-interval=${REPORT_INTERVAL} \
        run
    " | tee "${RUN_DIR}/sysbench.log"

    ./collect_metrics_stop.sh

    for host in "${DB_NODES[@]}"; do
      HOST_DIR="${RUN_DIR}/${host}"
      mkdir -p "$HOST_DIR"

      scp_from "$host" "~/metrics/mpstat.log" "${HOST_DIR}/mpstat.log" || true
      scp_from "$host" "~/metrics/sar_net.log" "${HOST_DIR}/sar_net.log" || true
      scp_from "$host" "~/metrics/vmstat.log" "${HOST_DIR}/vmstat.log" || true
      scp_from "$host" "cockroach.log" "${HOST_DIR}/cockroach.log" || true
    done

    echo "Sleeping 10 seconds before next run..."
    sleep 10
  done
done

echo "Parsing sysbench logs into CSV..."
python3 ./parse_results.py "$RESULT_DIR"

echo "Benchmark finished. Summary CSV:"
echo "  ${RESULT_DIR}/summary.csv"
