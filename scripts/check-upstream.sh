#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mode=${1:-}
[[ -z "$mode" || "$mode" == --update ]] || { echo 'Usage: check-upstream.sh [--update]' >&2; exit 1; }
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
headers=(-H 'Accept: application/vnd.github+json')
if [[ -n ${GH_TOKEN:-} ]]; then headers+=(-H "Authorization: Bearer $GH_TOKEN"); fi
curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 --max-time 60 \
    "${headers[@]}" https://api.github.com/repos/Manager-io/Manager/releases/latest -o "$tmp"
python3 - "$tmp" "$mode" <<'PY'
import json, os, re, sys
from pathlib import Path
release = json.loads(Path(sys.argv[1]).read_text())
latest = release['tag_name']
current = Path('MANAGER_VERSION').read_text().strip()
pattern = r'[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
if not all(re.fullmatch(pattern, v) for v in (latest, current)):
    raise SystemExit('Invalid four-part Manager version')
if release['draft'] or release['prerelease']:
    raise SystemExit('Refusing draft/prerelease')
for arch in ('x64', 'arm64'):
    assets = [a for a in release['assets'] if a['name'] == f'ManagerServer-linux-{arch}.tar.gz']
    if len(assets) != 1 or not re.fullmatch(r'sha256:[0-9a-f]{64}', assets[0].get('digest') or ''):
        raise SystemExit(f'Missing {arch} asset or SHA-256 digest')
newer = tuple(map(int, latest.split('.'))) > tuple(map(int, current.split('.')))
print(f'Current: {current}\nUpstream: {latest}\nNewer: {str(newer).lower()}')
if sys.argv[2] == '--update' and newer:
    Path('MANAGER_VERSION').write_text(latest + '\n')
if os.environ.get('GITHUB_OUTPUT'):
    with open(os.environ['GITHUB_OUTPUT'], 'a') as out:
        out.write(f'latest={latest}\nnewer={str(newer).lower()}\n')
PY
