#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

echo "Cleaning up sysbench tables..."
ssh_exec "$CLIENT" "
  sysbench \
    --db-driver=pgsql \
    --db-ps-mode=disable \
    oltp_read_write \
    --pgsql-host=${NODE1} \
    --pgsql-port=${DB_PORT} \
    --pgsql-user=root \
    --pgsql-db=${DB_NAME} \
    --tables=${TABLES} \
    --table-size=${TABLE_SIZE} \
    cleanup
"
