#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

echo "Creating database if not exists..."
ssh_exec "$CLIENT" "
  cockroach sql --insecure --host=${NODE1}:${DB_PORT} -e '
    CREATE DATABASE IF NOT EXISTS ${DB_NAME};
  '
"

echo "Verifying database..."
ssh_exec "$CLIENT" "
  cockroach sql --insecure --host=${NODE1}:${DB_PORT} --database=${DB_NAME} -e '
    SHOW DATABASES;
    SHOW SCHEMAS;
  '
"

echo "Preparing sysbench dataset..."
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
    prepare
"

echo "Checking created tables..."
ssh_exec "$CLIENT" "
  cockroach sql --insecure --host=${NODE1}:${DB_PORT} --database=${DB_NAME} -e '
    SHOW TABLES;
  '
"
