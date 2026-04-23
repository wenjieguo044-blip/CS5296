#!/usr/bin/env bash
set -euo pipefail
source ./config.sh

BOOTSTRAP_KEY="${BOOTSTRAP_KEY:-$HOME/.ssh/ec2_gwj.pem}"

echo "[1/5] Checking bootstrap key..."
if [[ ! -f "$BOOTSTRAP_KEY" ]]; then
  echo "ERROR: bootstrap key not found: $BOOTSTRAP_KEY"
  echo "Please upload ec2_gwj.pem to client first."
  exit 1
fi
chmod 400 "$BOOTSTRAP_KEY" || true

echo "[2/5] Ensuring client SSH key exists..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ ! -f "$SSH_KEY" ]]; then
  echo "  -> generating $SSH_KEY"
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
else
  echo "  -> found $SSH_KEY"
fi

if [[ ! -f "${SSH_KEY}.pub" ]]; then
  echo "ERROR: public key not found: ${SSH_KEY}.pub"
  exit 1
fi

PUBKEY="$(cat "${SSH_KEY}.pub")"

echo "[3/5] Enabling client self-SSH..."
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
grep -qxF "$PUBKEY" ~/.ssh/authorized_keys || echo "$PUBKEY" >> ~/.ssh/authorized_keys

echo "[4/5] Pushing client public key to DB nodes using bootstrap key..."
for host in "${DB_NODES[@]}"; do
  echo "  -> configuring $host"
  cat "${SSH_KEY}.pub" | ssh -i "$BOOTSTRAP_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "${SSH_USER}@${host}" \
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
done

echo "[5/5] Verifying SSH..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@127.0.0.1" "echo OK-self" || true

for host in "${DB_NODES[@]}"; do
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${host}" "echo OK-${host}"
done

echo "Bootstrap completed successfully."
echo "Now client can use SSH_KEY=$SSH_KEY for all later scripts."
