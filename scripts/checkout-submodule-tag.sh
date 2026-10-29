#!/usr/bin/env bash
# ./scripts/checkout-submodule-tag.sh v1.26.7
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <tag>" >&2
  echo "Example: $(basename "$0") v1.26.7" >&2
}

if [[ $# -ne 1 || -z "${1:-}" ]]; then
  usage
  exit 1
fi

TAG="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE="${ROOT}/Cli-Proxy-API-Management-Center"

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

cd "$SUBMODULE"
git reset --hard
git clean -fd
git fetch origin --tags
git fetch origin
git checkout "$TAG"

echo "Checked out ${TAG} ($(git rev-parse --short HEAD)) in Cli-Proxy-API-Management-Center"
