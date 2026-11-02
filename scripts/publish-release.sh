#!/usr/bin/env bash
# Tag this repo with a composite ref, push, and publish a GitHub release (triggers CI).
# Requires: gh auth login, push access to origin.
#
# ./scripts/publish-release.sh --app v1.26.7 --nono 0.81.0
# ./scripts/publish-release.sh v1.26.7
# ./scripts/publish-release.sh v1.26.7-0.81.0
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") --app <upstream-tag> [--nono <semver>]" >&2
  echo "       $(basename "$0") [<upstream-tag> | <composite-tag>]" >&2
  echo "  --app   Upstream app tag (e.g. v1.26.7); --nono defaults to 0.81.0 or NONO_VERSION" >&2
  echo "  No args: use submodule HEAD (must be exactly on a git tag)" >&2
  echo "Example: $(basename "$0") --app v1.26.7 --nono 0.81.0  # git/docker tag v1.26.7-0.81.0" >&2
  echo "Example: $(basename "$0") v1.26.7-0.81.0" >&2
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/parse-release-tag.sh
source "${ROOT}/scripts/lib/parse-release-tag.sh"
# shellcheck source=lib/resolve-release-args.sh
source "${ROOT}/scripts/lib/resolve-release-args.sh"
SUBMODULE="${ROOT}/Cli-Proxy-API-Management-Center"
DOCKER_IMAGE="${DOCKER_IMAGE:-bbkudk/cli-proxy-api-management-center-secure}"

set +e
resolve_release_tag_args "$@"
rc=$?
set -e
if [[ "$rc" -eq 2 ]]; then
  usage
  exit 0
elif [[ "$rc" -ne 0 ]]; then
  usage
  exit 1
fi

if ! git -C "$SUBMODULE" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Submodule not initialized at ${SUBMODULE}." >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install: https://cli.github.com/" >&2
  exit 1
fi

if [[ "${RESOLVE_FROM_SUBMODULE:-0}" -eq 1 ]]; then
  upstream_tag="$(git -C "$SUBMODULE" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ -z "$upstream_tag" ]]; then
    echo "Submodule HEAD is not exactly on a git tag." >&2
    echo "Pass --app v1.26.7 or a positional tag." >&2
    exit 1
  fi
  export NONO_VERSION
  parse_release_tag "$upstream_tag"
else
  "${ROOT}/scripts/checkout-submodule-tag.sh" "$BASE_TAG"
fi

RELEASE_TAG="$DOCKER_TAG"

if ! git -C "$SUBMODULE" rev-parse "refs/tags/${BASE_TAG}^{commit}" >/dev/null 2>&1; then
  echo "Tag ${BASE_TAG} not found in submodule." >&2
  exit 1
fi

cd "$ROOT"

if git rev-parse "refs/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
  echo "Tag ${RELEASE_TAG} already exists in this repository." >&2
  echo "Use ./scripts/re-release.sh ${RELEASE_TAG} to rebuild the same tag." >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
  echo "Tag ${RELEASE_TAG} already exists on origin." >&2
  exit 1
fi

if ! git diff --quiet -- Cli-Proxy-API-Management-Center; then
  git add Cli-Proxy-API-Management-Center
  git commit -m "Pin Cli-Proxy-API-Management-Center at ${BASE_TAG}"
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

git tag -a "$RELEASE_TAG" -m "Release ${RELEASE_TAG} (Management Center ${BASE_TAG} + nono ${NONO_VERSION})"
git push origin "$RELEASE_TAG"

NOTES_FILE="$(mktemp)"
trap 'rm -f "$NOTES_FILE"' EXIT
{
  echo "Docker image \`${DOCKER_IMAGE}:${RELEASE_TAG}\`."
  echo
  echo "Built from [router-for-me/Cli-Proxy-API-Management-Center](https://github.com/router-for-me/Cli-Proxy-API-Management-Center) at \`${BASE_TAG}\` (nono ${NONO_VERSION}), with deployment overlay from this repo."
  echo
  echo "Submodule commit: \`$(git -C "$SUBMODULE" rev-parse --short HEAD)\`"
} >"$NOTES_FILE"

gh release create "$RELEASE_TAG" \
  --title "$RELEASE_TAG" \
  --notes-file "$NOTES_FILE"

echo "Published release ${RELEASE_TAG}. CI will push ${DOCKER_IMAGE}:${RELEASE_TAG} to Docker Hub."
