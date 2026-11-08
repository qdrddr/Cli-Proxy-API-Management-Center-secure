# Cli-Proxy-API-Management-Center-secure

Docker image for the **[CLI Proxy API Management Center](https://github.com/router-for-me/Cli-Proxy-API-Management-Center)** UI, wrapped in **[nono](https://github.com/nolabs-ai/nono)** (nginx + socat to CLIProxyAPI).

**Default image:** `bbkudk/cli-proxy-api-management-center-secure:<canonical-tag>` (e.g. `v1.27.2-v0.81.0`).

## Release

Git tag, GitHub release name, and Docker Hub tag are the same: **`v{app}-v{nono}`** (e.g. `v1.27.3-v0.81.0`).

**Publish release** (pins upstream submodule, creates tag + GitHub release, tag push builds the image):

```bash
./scripts/publish-release.sh --app v1.27.3 --nono 0.81.0   # → v1.27.3-v0.81.0
./scripts/publish-release.sh v1.27.3-v0.81.0
./scripts/publish-release.sh v1.27.3-v0.81.0 --force      # retag + recreate release + CI
```

GitHub Actions → **Publish Release** → set **Release name** to `v1.27.3-v0.81.0` (optional **force retag**).

Tag-only (CI still runs; workflow creates the GitHub release if missing):

```bash
git tag -a v1.27.3-v0.81.0 -m "Management Center v1.27.3 + nono 0.81.0"
git push origin v1.27.3-v0.81.0
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
| `publish-release.sh` | Release name → pin, tag, GitHub release |
| `publish-release.yml` | Same via Actions (`release` input) |
| `re-release.sh` | Rebuild existing tag |
| `build-and-push-image.sh` | Local or CI image push |

Override image or nono default: `DOCKER_IMAGE`, `NONO_VERSION` (env or GitHub Actions variables).
