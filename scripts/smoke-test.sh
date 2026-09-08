#!/bin/bash
set -Eeuo pipefail
image=${1:-managerio-docker:local}
[[ ${SMOKE_TIMEOUT:-120} =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid SMOKE_TIMEOUT' >&2; exit 1; }
container=""
volume=""
cleanup() {
    status=$?
    trap - EXIT
    if [[ -n "$container" ]]; then
        if (( status != 0 )); then docker logs "$container" >&2 || true; fi
        docker rm -f -v "$container" >/dev/null || status=1
    fi
    if [[ -n "$volume" ]]; then docker volume rm "$volume" >/dev/null || status=1; fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
volume=$(docker volume create)
start() {
    container=$(docker run -d -p 127.0.0.1::8080 -v "$volume:/data" "$image")
    port=$(docker port "$container" 8080/tcp)
    url="http://${port}"
    deadline=$((SECONDS + ${SMOKE_TIMEOUT:-120}))
    until curl --fail --silent --max-time 3 "$url/healthz" >/dev/null; do
        [[ $(docker inspect -f '{{.State.Running}}' "$container") == true ]] || return 1
        (( SECONDS < deadline )) || { echo 'Manager startup timed out' >&2; return 1; }
        sleep 2
    done
    curl --fail --silent --show-error --max-time 10 "$url/" >/dev/null
    # Inspect the actual PID 1 identity, not the default root identity of docker exec.
    docker exec "$container" sh -c 'test "$(awk "/^Uid:/ {print \$2}" /proc/1/status)" != 0 && test "$(cat /proc/1/comm)" = ManagerServer'
}
stop_gracefully() {
    docker stop --time 30 "$container" >/dev/null
    code=$(docker inspect -f '{{.State.ExitCode}}' "$container")
    [[ "$code" == 0 || "$code" == 143 ]] || { echo "Unexpected shutdown exit code: $code (137 means forced kill)" >&2; return 1; }
}
start
docker exec "$container" /usr/local/bin/chromium-wrapper --version
docker exec --user 1000:1000 "$container" sh -c 'printf "persistent\n" > /data/.smoke-persistence'
stop_gracefully
docker rm -v "$container" >/dev/null
container=""
start
docker exec --user 1000:1000 "$container" sh -c 'test "$(cat /data/.smoke-persistence)" = persistent'
stop_gracefully
echo 'Smoke test passed: HTTP, health, non-root PID 1, Chromium, stop and volume recreation.'
