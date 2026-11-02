# CLI Proxy API Management Center (secure nono SBX)

Thin wrapper around [router-for-me/Cli-Proxy-API-Management-Center](https://github.com/router-for-me/Cli-Proxy-API-Management-Center): copies `deployment/docker/` into the submodule, builds, and pushes a Docker image.

**Default image:** `bbkudk/cli-proxy-api-management-center-secure:<composite-tag>` (e.g. `v1.26.7-0.81.0`).

## First release (new composite tag)

```bash
git submodule update --init --recursive
git checkout main && git pull
./scripts/publish-release.sh --app v1.26.7 --nono 0.81.0   # creates v1.26.7-0.81.0
```

Creates composite git tag + GitHub release → CI builds and pushes the image (`build` environment needs `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN`).

## Tag-only release

```bash
git tag -a v1.26.7-0.81.0 -m "Management Center v1.26.7 + nono 0.81.0"
git push origin v1.26.7-0.81.0
```

Pushing a composite tag runs CI; a GitHub Release is created automatically after a successful build if one does not exist.

## Re-run build for an existing tag

```bash
./scripts/re-release.sh --app v1.26.7 --nono 0.81.0
./scripts/re-release.sh v1.26.7-0.81.0           # CI from main (same Docker tag)
./scripts/re-release.sh v1.26.7-0.81.0 --local   # docker login, then build & push locally
./scripts/re-release.sh v1.26.7-0.81.0 --retag   # move composite git tag to HEAD, force-push
```

Legacy upstream-only tags (e.g. `v1.26.7`) still trigger CI via **GitHub Release published**.

## Scripts

| Script | Purpose |
|--------|---------|
| `lib/parse-release-tag.sh` | Parse upstream or composite refs |
| `publish-release.sh` | Composite tag wrapper repo, push, `gh release create` |
| `re-release.sh` | Rebuild an existing tag (CI or `--local`) |
| `build-and-push-image.sh` | Checkout submodule tag, copy docker files, build & push |
| `checkout-submodule-tag.sh` | Submodule only |
| `copy-deployment-docker.sh` | Rsync overlay only |

Override image or nono version: `DOCKER_IMAGE`, `NONO_VERSION` (env or GitHub Actions variables).
