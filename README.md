# CLI Proxy API Management Center (secure nono SBX)

Thin wrapper around [router-for-me/Cli-Proxy-API-Management-Center](https://github.com/router-for-me/Cli-Proxy-API-Management-Center): copies `deployment/docker/` into the submodule, builds, and pushes a Docker image.

**Default image:** `bbkudk/cli-proxy-api-management-center-secure:<tag>`

## First release (new tag)

```bash
git submodule update --init --recursive
git checkout main && git pull
./scripts/publish-release.sh v1.26.7   # upstream tag must exist
```

Creates git tag + GitHub release → CI builds and pushes the image (`build` environment needs `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN`).

## Re-run full release flow for an existing tag (new image name, overlay, or Dockerfile)

`publish-release.sh` refuses if the tag already exists.

```bash
./scripts/re-release.sh v1.26.7           # CI from main
./scripts/re-release.sh v1.26.7 --local   # docker login, then build & push locally
```

Re-running an old **Release** workflow job on the tag commit does not pick up changes on `main` unless you set the `DOCKER_IMAGE` repo variable.

## Scripts

| Script | Purpose |
|--------|---------|
| `publish-release.sh` | Tag wrapper repo, push, `gh release create` |
| `re-release.sh` | Rebuild an existing tag (CI or `--local`) |
| `build-and-push-image.sh` | Checkout submodule tag, copy docker files, build & push |
| `checkout-submodule-tag.sh` | Submodule only |
| `copy-deployment-docker.sh` | Rsync overlay only |

Override image or nono version: `DOCKER_IMAGE`, `NONO_VERSION` (env or GitHub Actions variables).
