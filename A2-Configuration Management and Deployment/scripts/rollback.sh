#!/usr/bin/env bash
set -euo pipefail
PREV_VERSION="${1:-v1}"
echo "==> Rollback to version: $PREV_VERSION"
"$(dirname "${BASH_SOURCE[0]}")/deploy.sh" "$PREV_VERSION"
echo "==> Rollback finished."
