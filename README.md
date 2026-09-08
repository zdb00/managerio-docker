# Manager.io Docker

A community-maintained Docker image for running Manager.io Server Edition, with amd64/arm64 builds, GHCR publishing and first-class Unraid support.

[![CI](https://github.com/zdb00/managerio-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/zdb00/managerio-docker/actions/workflows/ci.yml)
[![Publish](https://github.com/zdb00/managerio-docker/actions/workflows/publish.yml/badge.svg)](https://github.com/zdb00/managerio-docker/actions/workflows/publish.yml)
[![GHCR](https://img.shields.io/badge/image-GHCR-blue)](https://github.com/zdb00/managerio-docker/pkgs/container/managerio-docker)
![Architectures](https://img.shields.io/badge/platforms-amd64%20%7C%20arm64-blue)
[![Packaging licence: MIT](https://img.shields.io/badge/packaging_licence-MIT-green)](LICENSE)

The selected upstream version lives in [MANAGER_VERSION](MANAGER_VERSION). Version numbers below are examples; available images depend on maintainer publication, not just upstream availability.

> **First publication:** this repository was created without a Git remote. Replace `zdb00` in this README, `compose.yaml`, `.env.example`, `Dockerfile` and the Unraid template with your lower-case GitHub owner before distributing it. Workflows determine the actual owner automatically. The image must be published before the installation commands can pull it.

## Important notice

This is an **unofficial community packaging project**, unaffiliated with Manager.io or NGSoftware. **Manager.io Server Edition is proprietary/commercial software.** Its licensing requirements apply; users are responsible for obtaining an appropriate Server Edition licence for production use. This project neither provides a Manager licence nor bypasses licensing. Check your entitlement before choosing a version. See [Manager Server licensing](https://www2.manager.io/server/pricing/).

The MIT licence covers only the original packaging files in this repository. It does **not** license Manager itself. No Manager source code or binaries are committed here.

## Features

- Native amd64 and arm64 CI builds and smoke tests; multi-platform GHCR publication.
- Persistent `/data`, configurable numeric identity, graceful signal delivery and an HTTP healthcheck.
- Debian Chromium for Manager's Puppeteer-based printing/PDF rendering.
- Docker, Compose and an Unraid user-template; no privileged mode or host networking needed.
- Version-pinned downloads with SHA-256 verification, reviewed releases and daily upstream monitoring.
- SHA-pinned Actions, Dependabot, BuildKit provenance, SBOM and GitHub image attestation.

## Quick Start

After the maintainer has published the image, run this on a trusted Docker host. Replace the host path and choose UID/GID values appropriate for that directory (`id -u` and `id -g` on Linux).

```bash
docker run -d \
  --name managerio \
  --restart unless-stopped \
  --stop-timeout 30 \
  -p 8080:8080 \
  -v /path/to/manager-data:/data \
  -e TZ=Australia/Perth \
  -e PUID=1000 -e PGID=1000 -e UMASK=0027 \
  ghcr.io/zdb00/managerio-docker:latest
```

Open `http://YOUR_SERVER_IP:8080/` from your trusted network. Complete Manager's setup and protect administrator access before enabling remote access.

**For production/accounting data, prefer an exact version**, for example replace the last line with:

```text
ghcr.io/zdb00/managerio-docker:26.8.4.3664
```

`latest` moves when a maintainer promotes a release. An exact tag selects a specific Manager version. Neither tag causes a running container to upgrade itself.

## Docker Compose

```bash
git clone https://github.com/zdb00/managerio-docker.git
cd managerio-docker
cp .env.example .env
# Edit .env: set MANAGER_IMAGE to a published exact tag, and check data path / IDs.
docker compose config
docker compose up -d
docker compose logs -f managerio
```

The default data bind mount is `./data`, relative to the Compose project. Set `MANAGER_DATA_PATH` to an absolute path if preferred. This must be a dedicated Manager directory. Set `MANAGER_PORT=8280` when host port 8080 is occupied. Set `MANAGER_BIND_ADDRESS=127.0.0.1` if only a reverse proxy on this host should reach the service.

`docker compose down` removes the container and network; it does not delete the bind-mounted data. Do not run two Manager containers against the same data directory.

## Unraid Installation

### Method 1 — manually add container

1. Open the Unraid WebGUI. Confirm Docker is enabled under **Settings → Docker**, then open the **Docker** tab and choose **Add Container**.
2. Select a blank template. Enable **Advanced View** if needed to show WebUI and Extra Parameters.
3. Enter these settings. Use an exact published image tag for production.

| Field | Value |
| --- | --- |
| Name | `Manager.io` |
| Repository | `ghcr.io/zdb00/managerio-docker:26.8.4.3664` |
| Network Type | `bridge` |
| Privileged | Off |
| WebUI | `http://[IP]:[PORT:8080]/` |
| Extra Parameters | `--restart=unless-stopped --stop-timeout=30` |

4. Click **Add another Path, Port, Variable, Label or Device** for each mapping below. Choose its indicated type. Paths need **Read/Write** access; the port uses **TCP**.

| Type | Name | Container target / variable key | Host value |
| --- | --- | --- | --- |
| Port | Web port | `8080` | `8080` |
| Path | Application data | `/data` | `/mnt/user/appdata/managerio` |
| Variable | Timezone | `TZ` | `Australia/Perth` or your IANA timezone |
| Variable | User ID | `PUID` | `99` |
| Variable | Group ID | `PGID` | `100` |
| Variable | File creation mask | `UMASK` | `0027` |

The numeric identity `99:100` is common for Unraid's nobody/users ownership. Confirm it matches your appdata permissions; image defaults are the more portable `1000:1000`. Do not enable privileged mode to fix permissions.

5. If 8080 is already used, change **Host Port** to `8280`, leaving **Container Port** at `8080`: **Host 8280 → Container 8080**. Browse to `http://YOUR_UNRAID_IP:8280/`.
6. Click **Apply**, wait for the pull to finish, then open the container icon → **WebUI**. Inspect **Logs** if it fails. Enable Unraid's **Autostart** toggle if it should start when your array starts.
7. Confirm `/mnt/user/appdata/managerio` is on persistent storage, arrange backups, and complete Manager's setup. Container removal/recreation preserves that directory.

### Method 2 — install the supplied user-template

The [XML template](unraid/managerio.xml) supplies the same fields. Download it from this repository, replace the owner placeholder if still present, and inspect it before installation. On Unraid, store it as:

```text
/boot/config/plugins/dockerMan/templates-user/my-managerio.xml
```

For example, after the repository is public, use Unraid's terminal:

```bash
mkdir -p /boot/config/plugins/dockerMan/templates-user
curl --fail --location \
  https://raw.githubusercontent.com/zdb00/managerio-docker/main/unraid/managerio.xml \
  -o /boot/config/plugins/dockerMan/templates-user/my-managerio.xml
```

Use that filename only if it will not overwrite an existing custom template. Return to **Docker → Add Container**, select **Manager.io** from the user-template list (refresh the page if needed), review every field, and change `:latest` to the exact version you intend to deploy. Apply and open WebUI.

This is a **user-template**, not a Community Applications listing. Including XML in GitHub does not submit or approve the app for the Apps store. See [Unraid's application documentation](https://docs.unraid.net/unraid-os/manual/applications/) for template storage and application management.

## Persistent Data

`/data` holds Manager's persistent application/business data. Only this directory needs persistence; Chromium home/cache files under `/tmp` are disposable. Application logs go to Docker stdout/stderr.

Always bind `/data` to a known host directory or explicitly named Docker volume. Without an explicit mount, Docker creates an anonymous volume that is easy to lose track of. Never store business data or licence keys in this repository or image build context. The Docker build context uses an allowlist.

## Backups

**Back up before every Manager version upgrade.** For accounting data, a successful image pull is not a recovery plan.

1. Use Manager's own business backup/export functionality.
2. Back up the entire host directory mounted at `/data`.
3. Keep protected off-server/off-site copies, plus a record of the Manager image version/digest.
4. Test restoration into an isolated instance periodically.

A raw copy while Manager is writing is **not guaranteed to be transaction-consistent**. Stop Manager for filesystem backups, or use a snapshot strategy whose application consistency you have established. For the default Compose layout:

```bash
docker compose stop managerio
mkdir -p backups
# Run with sufficient read permissions; protect this archive as sensitive data.
tar -czf "backups/manager-data-$(date +%Y%m%d-%H%M%S).tar.gz" -C data .
docker compose start managerio
```

Check the backup command succeeded before relying on the archive. Adapt the source path if you changed `MANAGER_DATA_PATH`; copy the backup off the Docker host securely. Unraid users can stop the container in the Docker tab, back up `/mnt/user/appdata/managerio`, then start it again.

## Restoring

Stop the container. Preserve the current data directory separately, restore a verified backup to the configured host path, and check its ownership. Start the **matching Manager version**, inspect health/logs, then verify businesses and reports in Manager. Use Manager's application-level import/backup functionality when restoring an individual business.

Do not assume an older Manager version can read data written by a newer version. Keep the original backup untouched while testing restoration.

## Upgrading

Follow **backup → inspect release → pull selected version → recreate → verify health → verify Manager**.

Review [upstream releases](https://github.com/Manager-io/Manager/releases), licence eligibility and this repository's release notes. After a successful backup:

```bash
# Replace VERSION with the reviewed four-part release number.
docker pull ghcr.io/zdb00/managerio-docker:VERSION
# Edit .env and set MANAGER_IMAGE to that exact same image:VERSION.
docker compose up -d --force-recreate managerio
docker compose ps
docker compose logs --tail=100 managerio
curl --fail http://127.0.0.1:8080/healthz
```

Then log into Manager, check business data and run a representative report/PDF export. Container replacement preserves the bind-mounted `/data`.

For `docker run`, stop and remove the old container, then repeat your saved run command with the new image tag and the **same data mount**. On Unraid, edit **Repository** to the reviewed exact tag and Apply after backing up. Disable automatic update jobs for this container.

## Downgrading

Application/database changes can make downgrades unsafe. This project does not promise backward compatibility. Prefer restoring a matching **pre-upgrade backup** into a separate directory and using its corresponding image version. Preserve the newer data until recovery is confirmed.

## Image Tags

| Tag | Meaning |
| --- | --- |
| `latest` | Last explicitly promoted Manager release; may move. |
| `26.8.4.3664` (example) | Exactly that upstream Manager version. Recommended for production. |
| `@sha256:…` | Immutable image content digest, for deployments requiring byte-for-byte identity. |

There are no SemVer-derived major/minor tags: Manager uses four numeric parts. An exact version tag can be rebuilt for packaging/base security fixes, so its **image digest may change**, but it must always contain the same Manager version. Record/pin a digest if packaging immutability is also required. Rebuilding requires explicit publication; there is no automatic production update.

## Architectures

`linux/amd64` maps to `ManagerServer-linux-x64.tar.gz`; `linux/arm64` maps to `ManagerServer-linux-arm64.tar.gz`. Docker selects the native platform from the published multi-platform image. Unsupported architectures fail the build clearly. CI uses native GitHub-hosted runners for both architectures; publication uses Buildx and QEMU.

## Ports

`8080/tcp` serves Manager over HTTP. Change the **host** port when needed, retaining container port 8080 so the built-in healthcheck remains valid.

## Volumes

| Container path | Purpose |
| --- | --- |
| `/data` | Persistent Manager application/business data; back up this mount. |

## Environment Variables

| Variable | Image default | Purpose |
| --- | --- | --- |
| `TZ` | `UTC` | IANA timezone; example Compose/Unraid configuration uses `Australia/Perth`. |
| `PUID` | `1000` | Nonzero runtime UID (1–999999999); Unraid template uses `99`. |
| `PGID` | `1000` | Nonzero runtime GID (1–999999999); Unraid template uses `100`. |
| `UMASK` | `0027` | New-file creation mask. `0002` allows group writes if intentionally needed. |
| `PUPPETEER_EXECUTABLE_PATH` | `/usr/local/bin/chromium-wrapper` | Manager/Puppeteer Chromium executable; normally leave unchanged. |

Compose-only settings in `.env`: `MANAGER_IMAGE` selects the image (default GHCR `latest`), `MANAGER_DATA_PATH=./data`, `MANAGER_PORT=8080`, and `MANAGER_BIND_ADDRESS=0.0.0.0`. These do not change Manager's internal port/path. `MANAGER_VERSION` is a **build argument/file**, not a runtime upgrade setting. `HOME` is set by the entrypoint to a disposable private directory under `/tmp`.

The entrypoint starts as root solely to prepare `/data` ownership, then uses `gosu` to exec as the selected numeric UID/GID. Manager becomes PID 1. Numeric identities avoid conflicts with Debian account names; `/etc/passwd` is not rewritten. The entrypoint changes ownership of the mount root only when needed and **never recursively chowns existing data**. Changing IDs on an existing installation requires an intentional, offline ownership migration.

Advanced users may supply `--user UID:GID` (nonzero UID). This skips ownership repair and ignores PUID/PGID; prepare the mount yourself. Read-only root filesystems require writable `/tmp` as well as `/data`. No privileged mode is required.

## Healthcheck

Every 30 seconds Docker requests `http://127.0.0.1:8080/healthz`, with a 5-second healthcheck timeout, 30-second startup grace and 3 retries. Runtime `curl` has a 4-second request limit.

```bash
docker ps
docker inspect --format '{{json .State.Health}}' managerio
curl --fail http://127.0.0.1:8080/healthz
```

Substitute your host port and container name (Unraid default: `Manager.io`). Health indicates HTTP liveness, not backup validity or accounting correctness. Docker's restart policy does not itself restart an unhealthy-but-running process.

## Reverse Proxy / HTTPS

Keep the backend on a **trusted network**. For remote access, terminate HTTPS with a properly configured reverse proxy such as Nginx Proxy Manager, Caddy or Traefik. Cloudflare Tunnel can provide an outbound tunnel where appropriate for your data policies; Tailscale is an option for private access. These are examples, not bundled components.

Do **not** simply forward port 8080 from your router to the public Internet. Restrict backend reachability, use HTTPS/private networking and protect Manager authentication. The default published host port listens on all interfaces; host firewall rules must match your intended access.

## Security Notes

Protect administrator credentials, patch the Docker host, protect backup copies, and treat business/accounting records as sensitive. Use a supported Manager version that your licence permits. No licence keys, passwords or real business data belong in image layers or Git.

Chromium is included because Manager uses browser rendering for PDF/printing. `PUPPETEER_EXECUTABLE_PATH` points to a wrapper using headless Chromium, `--disable-dev-shm-usage` and `--no-sandbox`. The last flag disables Chromium's own sandbox for container compatibility: retain Docker isolation, avoid privileged mode and only render trusted content. The Manager process remains non-root. TLS policy is not weakened.

Download integrity uses GitHub's official release-asset SHA-256 metadata. These digests are not an independent upstream signature; compromise of the upstream release/account remains a trust boundary. Builds fail if the digest is missing, the release/architecture is unavailable or verification fails. See [research and validation notes](docs/RESEARCH.md).

## Troubleshooting

### Container will not start

```bash
docker logs --tail=200 managerio
```

Check image name/tag, `/data` access and startup errors. Unraid's default name is `Manager.io`, so substitute it in commands.

### Permission denied on `/data`

Confirm the runtime PUID/PGID matches the dedicated host directory. Existing files are not recursively repaired. Stop Manager, back up, and intentionally fix ownership if changing IDs. For example, **only for this dedicated Unraid Manager directory**:

```bash
# Container must be stopped; confirm this is your actual Manager data path first.
chown -R 99:100 /mnt/user/appdata/managerio
```

Never apply this to an entire share containing other applications. NFS/root-squashed mounts may reject startup ownership repair; provision matching permissions and use an explicit non-root `--user` instead. Check nested directories and read-only mount settings.

### Port 8080 already in use

Use `-p 8280:8080`, set Compose `MANAGER_PORT=8280`, or change Unraid's host port. Browse to port 8280.

### Healthcheck failing

```bash
docker logs --tail=200 managerio
docker exec managerio curl --fail --verbose http://127.0.0.1:8080/healthz
docker inspect --format '{{json .State.Health}}' managerio
```

Check permissions and allow initial startup time. Overriding Manager's internal port/path invalidates the supplied healthcheck/data assumptions; host port remapping is preferred.

### PDF/printing/rendering problems

```bash
docker exec managerio /usr/local/bin/chromium-wrapper --version
docker exec managerio printenv PUPPETEER_EXECUTABLE_PATH
docker logs --tail=200 managerio
```

Check writable `/tmp`, available memory and Manager errors. The smoke test checks executable availability, not every business-specific PDF layout. Verify a representative export after upgrades.

### Wrong architecture

Only amd64 and arm64 are supported. Inspect with `docker buildx imagetools inspect IMAGE:TAG`. Prefer native platform selection; an `exec format error` often means the wrong platform or missing emulation.

## Building Locally

The Dockerfile evaluates `MANAGER_VERSION` from the build argument, falling back to the repository file when omitted. It never downloads `latest` at startup.

```bash
docker buildx build --load \
  --build-arg MANAGER_VERSION="$(cat MANAGER_VERSION)" \
  -t managerio-docker:local .
./scripts/smoke-test.sh managerio-docker:local

# Explicit version override:
docker build --build-arg MANAGER_VERSION=26.8.4.3664 -t managerio-docker:local .

# Multi-platform build (OCI archive; no registry publication):
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg MANAGER_VERSION="$(cat MANAGER_VERSION)" \
  --output type=oci,dest=/tmp/managerio-image.tar .
```

Pass `SOURCE_URL=https://github.com/OWNER/managerio-docker` as a build argument for local source metadata. Workflows supply both source and version labels automatically. A plain `docker build .` still selects the file's version, but leaves the OCI version label empty; the actual version is always recorded at `/opt/manager-server/MANAGER_VERSION`. Use the commands above or `make build` for complete version metadata.

The base is Microsoft's `runtime-deps:8.0-bookworm-slim`: supported .NET 8 native dependencies on Debian, without an SDK or full .NET runtime. Existing Manager packaging uses this generation; archive inspection shows a self-contained binary. Runtime compatibility must pass native CI before publication. Base/Chromium security updates enter on explicit rebuilds. Review the base's support lifecycle during maintenance.

Convenience commands: `make build`, `make run`, `make stop`, `make logs`, `make test`, `make clean`, `make upstream-version`. `make run` uses the local image; `make clean` removes Compose resources and preserves bind-mounted data. Run `./scripts/validate.sh` for static checks (Bash, Python 3 and Docker Compose CLI; optional actionlint and ShellCheck). This validation command does not contact the Docker daemon.

## Releases

Upstream release discovery never publishes an image. Publication requires a stable GitHub Release tagged **`v` + MANAGER_VERSION** (for example `v26.8.4.3664`) or a manual **Publish** dispatch. Pushing a tag alone, merging a PR or publishing a prerelease does not publish an image.

Manual dispatch accepts any selected stable official four-part version; blank uses `MANAGER_VERSION` at the selected ref. This override is tested and is used identically for download, labels and exact tag. Disable **update_latest** when rebuilding/publishing a historical version you do not want promoted. Stable repository Releases promote `latest`, so use manual dispatch for historical-only publication.

Both architectures must pass native CI before the publishing job runs. Buildx then publishes the exact Manager tag and, when selected, `latest`. Publishing jobs are serialized. The image contains BuildKit provenance and an SBOM; `actions/attest` records GitHub provenance against the pushed digest. A provenance record describes origin, not a security audit or a licence grant.

## Maintainer Release Process

### One-time GitHub setup

1. Create a **public** GitHub repository named `managerio-docker`. Replace `zdb00` as described above, commit these files and push to `main`.
2. Under **Settings → Actions → General**, enable Actions and permit the SHA-pinned actions used here. Enable **Allow GitHub Actions to create and approve pull requests** so the daily checker can create its PR. Workflow-level permissions provide only the required token scopes; no PAT or stored registry password is needed.
3. Under **Settings → Environments**, create **release**. Configure required reviewers and restrict deployment branches/tags to your trusted release refs if desired. The workflow uses this environment, but review protection only exists if you configure it.
4. Enable branch protection/rulesets for `main`, with human review and CI checks. Allow the checker to maintain `automation/manager-version`; do not grant it bypass rights for `main`.
5. Run **Actions → CI → Run workflow** on `main`. Review both native platform results. Do not treat the initial scaffold as runtime-verified until these pass.
6. Create a stable Release tagged `v26.8.4.3664` from the reviewed commit, or run **Actions → Publish → Run workflow** with the selected version. Approve the release environment if configured.
7. After the first successful push, open your profile/organization **Packages → managerio-docker → Package settings → Change visibility → Public** for anonymous pulls. A public Git repository does not automatically guarantee a public GHCR package. Confirm its source repository is connected and has Actions access if an older package already exists.
8. Test an anonymous pull and deploy to a disposable instance before production. Add a repository description/topics such as `manager-io`, `docker`, `unraid`, `accounting` and `ghcr` for discoverability.

### Each Manager update

1. The **Check upstream** workflow runs daily at **03:23 UTC**, or manually. It compares the official latest release with `MANAGER_VERSION` numerically and verifies both asset names/digests.
2. A single `automation/manager-version` branch/PR updates only `MANAGER_VERSION`; subsequent discoveries update that PR rather than creating duplicates. No version change means no PR.
3. The checker explicitly invokes reusable native CI on the proposed commit. GitHub-token-created PRs do not automatically trigger ordinary PR workflows. Inspect the **Check upstream** test jobs; run **CI** manually selecting `automation/manager-version` if a separate branch check is required by your ruleset.
4. Review upstream changes, backup/restore implications, licence eligibility and test results; merge the PR. The push to `main` also runs CI.
5. Create the correctly tagged stable repository Release or manually dispatch Publish. Review/approve deployment. Buildx publishes amd64/arm64, the exact tag and the selected `latest` promotion.
6. Inspect the registry image and attestation, and test with temporary data before announcing it:

```bash
docker buildx imagetools inspect ghcr.io/zdb00/managerio-docker:26.8.4.3664
gh attestation verify oci://ghcr.io/zdb00/managerio-docker:26.8.4.3664 \
  --repo zdb00/managerio-docker
```

Dependabot proposes weekly Actions/base-image maintenance. Review it like any other change; it cannot publish by merging. No Watchtower, startup downloader, or production auto-updater is installed.

## Licence

Original repository packaging is [MIT-licensed](LICENSE). **Manager.io remains proprietary**, with separate Server Edition licensing requirements. Chromium, Debian packages and Microsoft base-image components retain their own licences. OCI licence metadata includes `LicenseRef-Manager-Proprietary` alongside MIT to avoid presenting the bundled application as MIT software.

## Disclaimer

Unofficial and unaffiliated with Manager.io / NGSoftware. Provided without warranty. Users are responsible for licensing, secure operation, backups and verification of their accounting data.
