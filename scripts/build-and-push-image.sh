#!/usr/bin/env bash
# Build and push Management Center image (requires: docker login).
# ./scripts/build-and-push-image.sh
# ./scripts/build-and-push-image.sh v1.26.7
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [git-tag]" >&2
  echo "  No tag: build from submodule HEAD (must be exactly on a git tag)" >&2
  echo "  With tag: checkout tag, sync deployment/docker, then build and push" >&2
  echo "Example: $(basename "$0") v1.26.7" >&2
  echo "Env: DOCKER_IMAGE (default bbkudk/cli-proxy-api-management-center-secure), NONO_VERSION (default 0.80.0)" >&2
}

highest_version_tag() {
  git -C "$SUBMODULE" fetch origin --tags --quiet
  git -C "$SUBMODULE" tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | tail -n 1
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE="${ROOT}/Cli-Proxy-API-Management-Center"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cli-proxy-api-management-center-secure}"
NONO_VERSION="${NONO_VERSION:-0.80.0}"

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  TAG="$1"
  "${ROOT}/scripts/checkout-submodule-tag.sh" "$TAG"
else
  TAG="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$TAG" ]]; then
    echo "Submodule HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: ./scripts/build-and-push-image.sh v1.26.7" >&2
    exit 1
  fi
fi

"${ROOT}/scripts/copy-deployment-docker.sh"

IMAGE_REF="${DOCKER_IMAGE}:${TAG}"

cd "$SUBMODULE"
docker build \
  -f deployment/docker/Dockerfile \
  --build-arg "VERSION=${TAG}" \
  --build-arg "NONO_VERSION=${NONO_VERSION}" \
  -t "${IMAGE_REF}" \
  .

docker push "${IMAGE_REF}"
echo "Pushed ${IMAGE_REF}"

HIGHEST_TAG="$(highest_version_tag)"
if [[ -n "$HIGHEST_TAG" && "$TAG" == "$HIGHEST_TAG" ]]; then
  docker tag "${IMAGE_REF}" "${DOCKER_IMAGE}:latest"
  docker push "${DOCKER_IMAGE}:latest"
  echo "Pushed ${DOCKER_IMAGE}:latest (${TAG})"
else
  echo "Skipped :latest (newest semver tag is ${HIGHEST_TAG:-none}, built ${TAG})"
fi
