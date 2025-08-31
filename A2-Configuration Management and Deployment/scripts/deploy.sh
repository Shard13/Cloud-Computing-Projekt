#!/usr/bin/env bash
set -euo pipefail
VERSION="${1:-v1}"
export APP_VERSION="$VERSION"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> Deploy (version: $VERSION)"
# 1) Infra up (reuse Aufgabe 1 Terraform, expect variable immutable_version to trigger replacement)
if [ -d "$ROOT_DIR/../A1-immutable/terraform" ]; then
  TF_DIR="$ROOT_DIR/../A1-immutable/terraform"
elif [ -d "$ROOT_DIR/terraform" ]; then
  TF_DIR="$ROOT_DIR/terraform"
else
  TF_DIR="$ROOT_DIR/../terraform"
fi
if [ -d "$TF_DIR" ]; then
  echo "==> Terraform in $TF_DIR"
  pushd "$TF_DIR" >/dev/null
  terraform init -upgrade
  terraform apply -auto-approve -var="immutable_version=$VERSION"
  popd >/dev/null
else
  echo "WARN: Terraform dir not found. Skipping infra apply."
fi

# 2) App deploy via Ansible
ANS_DIR="$ROOT_DIR/ansible"
INV_PATH=""
# Prefer user's Aufgabe1 inventory if present
if [ -f "$ROOT_DIR/../A1-immutable/ansible/inventory/inventory.ini" ]; then
  INV_PATH="$ROOT_DIR/../A1-immutable/ansible/inventory/inventory.ini"
elif [ -f "$ROOT_DIR/../ansible/inventory/inventory.ini" ]; then
  INV_PATH="$ROOT_DIR/../ansible/inventory/inventory.ini"
else
  INV_PATH="$ANS_DIR/inventory/inventory.ini"
  echo "NOTE: Using local inventory at $INV_PATH. Update it with your VM IP."
fi
echo "==> Ansible app deploy using $INV_PATH"
ansible-playbook -i "$INV_PATH" "$ANS_DIR/app_deploy.yml" -e "app_version=$VERSION"
echo "==> Deploy finished."
