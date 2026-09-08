#!/bin/bash
set -Eeuo pipefail
fail() { echo "managerio: $*" >&2; exit 1; }
[[ ${UMASK:-0027} =~ ^0?[0-7]{3}$ ]] || fail 'UMASK must have three or four octal digits'
umask "${UMASK:-0027}"
if [[ $(id -u) == 0 ]]; then
    for value in "${PUID:-1000}" "${PGID:-1000}"; do
        [[ $value =~ ^[1-9][0-9]{0,8}$ ]] || fail 'PUID and PGID must be positive decimal IDs (1-999999999)'
    done
    mkdir -p /data
    if [[ $(stat -c '%u:%g' /data) != "${PUID:-1000}:${PGID:-1000}" ]]; then
        chown "${PUID:-1000}:${PGID:-1000}" /data
    fi
    exec gosu "${PUID:-1000}:${PGID:-1000}" "$0" "$@"
fi
HOME="/tmp/manager-home-$(id -u)"
export HOME
mkdir -p "$HOME"
chmod 0700 "$HOME"
[[ -d /data && -w /data && -x /data ]] || fail '/data must be writable by the runtime UID/GID; check bind-mount ownership'
[[ $# -gt 0 ]] || fail 'No command provided'
exec "$@"
