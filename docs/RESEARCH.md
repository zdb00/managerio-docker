# Research and validation record

Checked on 2026-09-08. These observations are a baseline, not a promise about future upstream releases.

## Official Manager release

The [official latest-release API](https://api.github.com/repos/Manager-io/Manager/releases/latest) returned `26.8.4.3664`, published `2026-08-04T06:04:52Z`, with these server assets:

| Platform | Exact asset | Format | GitHub asset SHA-256 |
| --- | --- | --- | --- |
| linux/amd64 | `ManagerServer-linux-x64.tar.gz` | gzip-compressed tar | `9296c42d4c4293e80c88949fdc09dc1a503ef1f7b1006ac868e2e0a79aad6fc2` |
| linux/arm64 | `ManagerServer-linux-arm64.tar.gz` | gzip-compressed tar | `18d41200cabededb7e08618dac7d3627aca632132a9b79420a7fcd4a8c7ad4df` |

The arm64 archive was downloaded into temporary storage for inspection. Its contents include `ManagerServer`, `libe_sqlite3.so` and `Assets/`; no full SDK installation or ZIP extraction is indicated. No upstream binaries are included in this repository.

The release has GitHub-provided asset digests, but no separate checksum/signature asset in the inspected asset list. The build queries the exact official release and validates the corresponding SHA-256 digest before extraction. This verifies the downloaded bytes against release metadata; it is not independent signed verification. Missing digests fail closed, including for older release overrides. The values above are research evidence, not another build-version configuration source.

Sources: [release page](https://github.com/Manager-io/Manager/releases/tag/26.8.4.3664), [exact release API](https://api.github.com/repos/Manager-io/Manager/releases/tags/26.8.4.3664).

## Base and browser

Microsoft documents [runtime-deps](https://github.com/dotnet/dotnet-docker/blob/main/README.runtime-deps.md) as native dependencies for self-contained applications, without .NET itself. .NET 8 is listed as LTS. The Debian-specific `8.0-bookworm-slim` tag keeps Debian Chromium available and avoids accidentally moving to a distribution with different Chromium packaging.

The maintained [AliYusuf95 Dockerfile](https://github.com/AliYusuf95/manager.io/blob/main/Dockerfile) uses runtime-deps 8.0, Debian Chromium, `PUPPETEER_EXECUTABLE_PATH` and `/healthz`; its [wrapper](https://github.com/AliYusuf95/manager.io/blob/main/chromium-wrapper) launches headless Chromium without its sandbox. [gabrielenterprises packaging](https://github.com/gabrielenterprises/docker_manager_io) uses the same browser environment integration. These are compatibility references, not sources of downloaded Manager binaries. This project adds non-root execution, download verification and `/dev/shm` mitigation.

Native container runtime validation remains required to establish compatibility for this repository's exact image. Browser executable presence alone does not prove every Manager PDF operation works.

## GitHub Actions and publication

Reviewed [GitHub's Docker publishing guide](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images), [GHCR authentication and visibility](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry), [Docker multi-platform CI](https://docs.docker.com/build/ci/github-actions/multi-platform/) and [Docker SBOM/provenance guidance](https://docs.docker.com/build/ci/github-actions/attestations/).

The implementation uses `GITHUB_TOKEN`, job-scoped publication permissions, Buildx/QEMU, raw four-part tags, and [actions/attest](https://github.com/actions/attest). Latest stable action tags were queried directly through each repository's GitHub release API and resolved to commits, rather than copying potentially old SHAs from documentation examples.

| Action | Verified stable release | Pinned commit |
| --- | --- | --- |
| [actions/checkout](https://github.com/actions/checkout) | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| [docker/setup-qemu-action](https://github.com/docker/setup-qemu-action) | v4.3.0 | `1f40c72289eff860ee54a304f1438e3cff362e0a` |
| [docker/setup-buildx-action](https://github.com/docker/setup-buildx-action) | v4.3.0 | `37fe631027851001ddb9b187196cc803df7f5f0e` |
| [docker/login-action](https://github.com/docker/login-action) | v4.6.0 | `dbcb813823bdd20940b903addbd779551569679f` |
| [docker/metadata-action](https://github.com/docker/metadata-action) | v6.2.0 | `dc802804100637a589fabce1cb79ff13a1411302` |
| [docker/build-push-action](https://github.com/docker/build-push-action) | v7.3.0 | `53b7df96c91f9c12dcc8a07bcb9ccacbed38856a` |
| [actions/attest](https://github.com/actions/attest) | v4.2.2 | `1e69f48acb82d1966a394da916b4c1698aa569d6` |
| [peter-evans/create-pull-request](https://github.com/peter-evans/create-pull-request) | v8.1.1 | `5f6978faf089d4d20b00c7766989d076bb2fc7f1` |

The upstream PR workflow explicitly calls reusable tests because events created with `GITHUB_TOKEN` ordinarily do not trigger additional workflows. See [GitHub's workflow trigger documentation](https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow).

## Unraid

The user-template uses the version-2 Container format with typed Config entries. Template storage and the distinction from Community Applications were checked against [Unraid documentation](https://docs.unraid.net/unraid-os/manual/applications/) and the [Docker manager implementation](https://github.com/unraid/webgui/blob/master/emhttp/plugins/dynamix.docker.manager/include/CreateDocker.php). XML structure has been validated locally; no live Unraid installation was available for UI testing.

## Local validation

Completed without using the Docker daemon after the user's explicit instruction:

- Bash/POSIX shell syntax and ShellCheck 0.11.0 passed.
- actionlint 1.7.12 passed, including embedded workflow shell checks.
- All workflow, Dependabot and Compose YAML parsed successfully.
- `docker compose --env-file .env.example config --quiet` passed; this only renders configuration.
- Unraid XML parsed; expected network, privilege setting, port, mount and variables were asserted.
- Six standard-library regression tests passed: numeric version ordering, unchanged/older releases, invalid versions/missing digests, unsupported architecture rejection, smoke-test success/recreation, and failure logging/cleanup for crashes, timeouts and forced kills. Docker and HTTP calls in these tests are explicitly mocked.
- The finished upstream checker successfully queried the live official API and reported no newer release.
- Final tracked-candidate files were inspected for unintended data, credentials and Manager binaries; none were found.

**Not performed:** image builds, actual Manager launch, real HTTP or `/healthz` requests, Chromium execution/PDF export, signal delivery to a real container, and data persistence across real container recreation. Docker Desktop startup was attempted before the user instructed not to use the daemon; no images were built or containers run. Runtime tests remain mandatory in CI before publishing. Automated smoke tests cover launch, HTTP, health, non-root PID 1, Chromium executable availability, graceful stop and a persistence marker across recreation; they do not validate business migrations or accounting results.

No Git remote or authenticated GitHub publication target existed. A local Git repository was initialized, but nothing has been committed, pushed or published. `YOUR_GITHUB_USERNAME` remains the intentional owner placeholder in installation files.
