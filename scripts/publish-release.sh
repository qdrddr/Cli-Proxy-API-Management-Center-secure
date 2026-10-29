#!/usr/bin/env bash
# Tag this repo with the Management Center submodule tag, push, and publish a GitHub release (triggers CI).
# Requires: gh auth login, push access to origin.
# ./scripts/publish-release.sh
# ./scripts/publish-release.sh v1.26.7
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [git-tag]" >&2
  echo "  No tag: use submodule HEAD (must be exactly on a git tag)" >&2
  echo "  With tag: checkout that tag in the submodule, then release" >&2
  echo "Example: $(basename "$0") v1.26.7" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE="${ROOT}/Cli-Proxy-API-Management-Center"

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install: https://cli.github.com/" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  TAG="$1"
  "${ROOT}/scripts/checkout-submodule-tag.sh" "$TAG"
else
  TAG="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$TAG" ]]; then
    echo "Submodule HEAD is not exactly on a git tag." >&2
    echo "Pass a tag: ./scripts/publish-release.sh v1.26.7" >&2
    exit 1
  fi
fi

if ! git -C "$SUBMODULE" rev-parse "refs/tags/${TAG}^{commit}" >/dev/null 2>&1; then
  echo "Tag ${TAG} not found in submodule." >&2
  exit 1
fi

cd "$ROOT"

if git rev-parse "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists in this repository." >&2
  echo "Delete locally/remotely first or choose another tag." >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists on origin." >&2
  exit 1
fi

if ! git diff --quiet -- Cli-Proxy-API-Management-Center; then
  git add Cli-Proxy-API-Management-Center
  git commit -m "Pin Cli-Proxy-API-Management-Center at ${TAG}"
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree has uncommitted changes. Commit or stash before releasing." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "HEAD" ]]; then
  UPSTREAM="$(git rev-parse --abbrev-ref "@{u}" 2>/dev/null || true)"
  if [[ -n "$UPSTREAM" ]]; then
    LOCAL="$(git rev-parse HEAD)"
    REMOTE="$(git rev-parse "$UPSTREAM" 2>/dev/null || true)"
    if [[ -n "$REMOTE" && "$LOCAL" != "$REMOTE" ]]; then
      echo "Pushing ${BRANCH} so the release tag points at commits on GitHub..."
      git push origin "HEAD:${BRANCH}"
    fi
  else
    echo "Branch ${BRANCH} has no upstream; pushing HEAD to origin..."
    git push origin HEAD
  fi
fi

git tag -a "$TAG" -m "Release ${TAG} (CLI Proxy API Management Center ${TAG})"
git push origin "$TAG"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
{
  echo "Docker image release for **${TAG}**, built from [router-for-me/Cli-Proxy-API-Management-Center](https://github.com/router-for-me/Cli-Proxy-API-Management-Center) at \`${TAG}\`."
  echo
  echo "Submodule commit: \`$(git -C "$SUBMODULE" rev-parse --short HEAD)\`"
} >"$NOTES_FILE"

gh release create "$TAG" \
  --title "$TAG" \
  --notes-file "$NOTES_FILE"

echo "Published release ${TAG}. CI workflow Release Docker Image should start shortly."
