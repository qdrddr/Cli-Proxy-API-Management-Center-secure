#!/usr/bin/env bash
# ./scripts/copy-deployment-docker.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/deployment/docker"
SUBMODULE="${ROOT}/Cli-Proxy-API-Management-Center"
DEST="${SUBMODULE}/deployment/docker"

if [[ ! -d "$SRC" ]]; then
  echo "Source not found: ${SRC}" >&2
  exit 1
fi

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
rsync -a --delete "${SRC}/" "${DEST}/"

echo "Copied deployment/docker -> Cli-Proxy-API-Management-Center/deployment/docker"
