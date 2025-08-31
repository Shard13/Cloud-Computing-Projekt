#!/usr/bin/env bash
set -euo pipefail
NEW_VERSION="${1:-v2}"
echo "==> Change (rolling forward) to version: $NEW_VERSION"
"$(dirname "${BASH_SOURCE[0]}")/deploy.sh" "$NEW_VERSION"
echo "==> Change finished."
