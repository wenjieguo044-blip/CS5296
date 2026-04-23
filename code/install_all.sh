#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

########################################
# Step 0: Check if SSH is connected.
########################################
check_ssh_ready() {
  echo "[0/4] Checking SSH connectivity..."

  for host in "${DB_NODES[@]}"; do
    echo "  -> testing SSH to $host"
    if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${host}" "echo ok-${host}" >/dev/null 2>&1; then
      echo "ERROR: SSH from client to ${host} is not ready."
      echo "Please run ./bootstrap_ssh.sh first."
      exit 1
    fi
  done

  echo "SSH connectivity is ready."
}

########################################
# Step 1: install CockroachDB（DB nodes）
########################################
install_cockroach_on_node() {
  local host="$1"
  echo "  -> Installing CockroachDB on $host"

  ssh_exec "$host" "
    set -e

    sudo pkill -9 cockroach || true
    sleep 2

    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y tar sysstat
    elif command -v apt >/dev/null 2>&1; then
      sudo apt update
      sudo apt install -y tar curl sysstat
    else
      echo 'Unsupported package manager'
      exit 1
    fi

    rm -rf cockroach-${CRDB_VERSION}.linux-amd64*
    curl -fsSLO https://binaries.cockroachdb.com/cockroach-${CRDB_VERSION}.linux-amd64.tgz
    tar -xzf cockroach-${CRDB_VERSION}.linux-amd64.tgz
    sudo cp cockroach-${CRDB_VERSION}.linux-amd64/cockroach /usr/local/bin/

    echo 'Cockroach version:'
    cockroach version
  "
}

########################################
# Step 2: install client tools
########################################
install_client_tools() {
  echo "[2/4] Installing client tools..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y tar python3 python3-pip sysstat nmap-ncat \
      git automake libtool pkgconfig make gcc gcc-c++ openssl-devel
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y tar curl python3 python3-pip sysstat netcat-openbsd \
      git automake libtool pkg-config make gcc g++ libssl-dev
  else
    echo "Unsupported package manager"
    exit 1
  fi

  rm -rf cockroach-${CRDB_VERSION}.linux-amd64*
  curl -fsSLO https://binaries.cockroachdb.com/cockroach-${CRDB_VERSION}.linux-amd64.tgz
  tar -xzf cockroach-${CRDB_VERSION}.linux-amd64.tgz
  sudo cp cockroach-${CRDB_VERSION}.linux-amd64/cockroach /usr/local/bin/

  cockroach version
}

########################################
# Step 3: install sysbench（client）
########################################
install_sysbench_on_client() {
  echo "[3/4] Installing sysbench..."

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf remove -y postgresql15-private-devel postgresql15-private-libs \
      postgresql15-devel libpq-devel || true
    sudo rm -f /usr/bin/pg_config || true

    sudo dnf install -y libpq-devel
  elif command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y libpq-dev
  else
    echo "Unsupported package manager"
    exit 1
  fi

  echo "Checking pg_config..."
  which pg_config || true
  pg_config --version

  rm -rf ~/sysbench
  git clone https://github.com/akopytov/sysbench.git ~/sysbench
  cd ~/sysbench

  ./autogen.sh
  ./configure --with-pgsql --without-mysql
  make -j
  sudo make install

  if ! command -v sysbench >/dev/null 2>&1; then
    sudo ln -sf /usr/local/bin/sysbench /usr/bin/sysbench
  fi

  echo "Sysbench version:"
  sysbench --version

  echo "Check pgsql support:"
  sysbench oltp_read_write help | grep pgsql || true
}

########################################
# main flow
########################################
echo "[config]"
echo "CLIENT=$CLIENT"
echo "DB_NODES=${DB_NODES[*]}"
echo "SSH_KEY=$SSH_KEY"

check_ssh_ready

echo "[1/4] Installing CockroachDB on DB nodes..."
for host in "${DB_NODES[@]}"; do
  install_cockroach_on_node "$host"
done

install_client_tools
install_sysbench_on_client

echo "[4/4] Installation completed successfully."
