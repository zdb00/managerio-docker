#!/bin/bash
set -Eeuo pipefail
version=${MANAGER_VERSION:-$(cat /build/MANAGER_VERSION)}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid Manager version' >&2; exit 1; }
case "${TARGETARCH:-}" in
    amd64) arch=x64 ;;
    arm64) arch=arm64 ;;
    *) echo "Unsupported TARGETARCH: ${TARGETARCH:-unset}" >&2; exit 1 ;;
esac
asset="ManagerServer-linux-${arch}.tar.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl_args=(--fail-with-body --silent --show-error --location --retry 3 --retry-all-errors --connect-timeout 15 --max-time 600)
api_headers=(-H 'Accept: application/vnd.github+json')
if [[ -s /run/secrets/github_token ]]; then
    api_headers+=(-H "Authorization: Bearer $(cat /run/secrets/github_token)")
fi
printf 'Fetching official Manager release metadata for %s (%s)\n' "$version" "$arch"
if curl "${curl_args[@]}" "${api_headers[@]}" "https://api.github.com/repos/Manager-io/Manager/releases/tags/$version" -o "$tmp/release.json"; then
    :
else
    status=$?
    echo 'GitHub release metadata request failed:' >&2
    if [[ -f "$tmp/release.json" ]]; then cat "$tmp/release.json" >&2; fi
    exit "$status"
fi
jq -e --arg version "$version" '.tag_name == $version and .draft == false and .prerelease == false' "$tmp/release.json" >/dev/null
digest=$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest | select(test("^sha256:[0-9a-f]{64}$"))' "$tmp/release.json")
printf 'Downloading %s\n' "$asset"
curl "${curl_args[@]}" "https://github.com/Manager-io/Manager/releases/download/$version/$asset" -o "$tmp/manager.tar.gz"
printf '%s  %s\n' "${digest#sha256:}" "$tmp/manager.tar.gz" | sha256sum --check --strict
mkdir -p /opt/manager-server
tar -xzf "$tmp/manager.tar.gz" -C /opt/manager-server --no-same-owner
test -f /opt/manager-server/ManagerServer
chmod 0755 /opt/manager-server/ManagerServer
printf '%s\n' "$version" > /opt/manager-server/MANAGER_VERSION
printf '%s\n' "$digest" > /opt/manager-server/UPSTREAM_DIGEST
