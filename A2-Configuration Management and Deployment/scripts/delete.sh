#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> Delete (app + infra)"
# 1) Try to remove app cleanly (optional)
ANS_DIR="$ROOT_DIR/ansible"
if [ -f "$ANS_DIR/app_delete.yml" ]; then
  if [ -f "$ROOT_DIR/../A1-immutable/ansible/inventory/inventory.ini" ]; then
    INV_PATH="$ROOT_DIR/../A1-immutable/ansible/inventory/inventory.ini"
  elif [ -f "$ROOT_DIR/../ansible/inventory/inventory.ini" ]; then
    INV_PATH="$ROOT_DIR/../ansible/inventory/inventory.ini"
  else
    INV_PATH="$ANS_DIR/inventory/inventory.ini"
  fi
  echo "==> Ansible app delete using $INV_PATH"
  ansible-playbook -i "$INV_PATH" "$ANS_DIR/app_delete.yml" || true
fi
# 2) Terraform destroy
if [ -d "$ROOT_DIR/../A1-immutable/terraform" ]; then
  TF_DIR="$ROOT_DIR/../A1-immutable/terraform"
elif [ -d "$ROOT_DIR/terraform" ]; then
  TF_DIR="$ROOT_DIR/terraform"
else
  TF_DIR="$ROOT_DIR/../terraform"
fi
if [ -d "$TF_DIR" ]; then
  echo "==> Terraform destroy in $TF_DIR"
  pushd "$TF_DIR" >/dev/null
  terraform destroy -auto-approve
  popd >/dev/null
else
  echo "WARN: Terraform dir not found. Skipping destroy."
fi
echo "==> Delete finished."
