#!/usr/bin/env bash
# Build and push Management Center image (requires: docker login).
# ./scripts/build-and-push-image.sh
# ./scripts/build-and-push-image.sh v1.26.7
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [git-tag]" >&2
  echo "  No tag: build from submodule HEAD (must be exactly on a git tag)" >&2
  echo "  With tag: checkout tag, sync deployment/docker, then build and push" >&2
  echo "Example: $(basename "$0") v1.27.2-v0.81.0  # canonical git + Docker Hub tag" >&2
  echo "         No tag: submodule HEAD tag + NONO_VERSION → v{app}-v{nono}" >&2
  echo "Env: DOCKER_IMAGE (default bbkudk/cli-proxy-api-management-center-secure), NONO_VERSION (default 0.81.0)" >&2
  echo "  DOCKER_PLATFORMS (optional, e.g. linux/amd64,linux/arm64) — uses buildx and --push" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
SUBMODULE="${ROOT}/Cli-Proxy-API-Management-Center"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cli-proxy-api-management-center-secure}"
NONO_VERSION="${NONO_VERSION:-0.81.0}"
DOCKER_PLATFORMS="${DOCKER_PLATFORMS:-}"

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  parse_release_tag "$1"
  "${ROOT}/scripts/checkout-submodule-tag.sh" "$BASE_TAG"
else
  upstream_tag="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$upstream_tag" ]]; then
    echo "Submodule HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: ./scripts/build-and-push-image.sh v1.27.2-v0.81.0" >&2
    exit 1
  fi
  canonical_release_tag "$upstream_tag" "${NONO_VERSION#v}"
fi

if [[ ! "$BASE_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Refusing unsafe tag: ${BASE_TAG}" >&2
  exit 1
fi

if [[ ! "$NONO_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing unsafe NONO_VERSION: ${NONO_VERSION}" >&2
  exit 1
fi

IMAGE_REF="${DOCKER_IMAGE}:${DOCKER_TAG}"

"${ROOT}/scripts/copy-deployment-docker.sh"

cd "$SUBMODULE"

if [[ -n "$DOCKER_PLATFORMS" ]]; then
  if ! docker buildx version >/dev/null 2>&1; then
    echo "docker buildx is required when DOCKER_PLATFORMS is set." >&2
    exit 1
  fi
  if [[ -n "${BUILDX_BUILDER:-}" ]]; then
    if ! docker buildx inspect "$BUILDX_BUILDER" >/dev/null 2>&1; then
      docker buildx create --name "$BUILDX_BUILDER" --driver docker-container --use
    else
      docker buildx use "$BUILDX_BUILDER"
    fi
  elif ! docker buildx inspect --bootstrap >/dev/null 2>&1; then
    BUILDER_NAME="cliproxy-multiarch"
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
    docker buildx inspect --bootstrap >/dev/null
  fi

  docker buildx build \
    -f deployment/docker/Dockerfile \
    --platform "$DOCKER_PLATFORMS" \
    --build-arg "VERSION=${BASE_TAG}" \
    --build-arg "NONO_VERSION=${NONO_VERSION}" \
    -t "$IMAGE_REF" \
    --push \
    .

  echo "Pushed multi-arch ${IMAGE_REF} (${DOCKER_PLATFORMS}; base ${BASE_TAG}, nono ${NONO_VERSION})"
else
  docker build \
    -f deployment/docker/Dockerfile \
    --build-arg "VERSION=${BASE_TAG}" \
    --build-arg "NONO_VERSION=${NONO_VERSION}" \
    -t "${IMAGE_REF}" \
    .

  docker push "${IMAGE_REF}"
  echo "Pushed ${IMAGE_REF} (base ${BASE_TAG}, nono ${NONO_VERSION})"
fi
