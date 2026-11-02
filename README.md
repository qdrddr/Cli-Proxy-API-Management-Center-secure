# Cli-Proxy-API-Management-Center-secure

Docker image for the **[CLI Proxy API Management Center](https://github.com/router-for-me/Cli-Proxy-API-Management-Center)** UI, wrapped in **[nono](https://github.com/nolabs-ai/nono)** (nginx + socat to CLIProxyAPI).

**Default image:** `bbkudk/cli-proxy-api-management-center-secure:<canonical-tag>` (e.g. `v1.27.2-v0.81.0`).

## Release

Git tag and Docker Hub tag are the same: **`v{app}-v{nono}`**.

```bash
./scripts/publish-release.sh --app v1.27.2 --nono 0.81.0   # creates v1.27.2-v0.81.0
./scripts/publish-release.sh v1.27.2-v0.81.0
```

Tag-only (CI on push):

```bash
git tag -a v1.27.2-v0.81.0 -m "Management Center v1.27.2 + nono 0.81.0"
git push origin v1.27.2-v0.81.0
```

Rebuild:

```bash
./scripts/re-release.sh --app v1.27.2 --nono 0.81.0
./scripts/re-release.sh v1.27.2-v0.81.0           # CI checks out git tag v1.27.2-v0.81.0
./scripts/re-release.sh v1.27.2-v0.81.0 --local   # docker login, then build & push locally
./scripts/re-release.sh v1.27.2-v0.81.0 --retag   # move composite git tag to HEAD, force-push
```

| Script | Purpose |
|--------|---------|
| `lib/parse-release-tag.sh` | Parse canonical refs |
| `lib/resolve-release-args.sh` | `--app` / `--nono` CLI |
| `publish-release.sh` | Tag + GitHub release |
| `re-release.sh` | Rebuild existing tag |
| `build-and-push-image.sh` | Local or CI image push |

Override image or nono default: `DOCKER_IMAGE`, `NONO_VERSION` (env or GitHub Actions variables).
