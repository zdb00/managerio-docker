#!/bin/bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for script in docker-entrypoint.sh scripts/*.sh; do bash -n "$script"; done
sh -n chromium-wrapper
python3 - <<'PY'
from pathlib import Path
import re, xml.etree.ElementTree as ET
version = Path('MANAGER_VERSION').read_text()
assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\n', version)
template = ET.parse('unraid/managerio.xml').getroot()
assert template.tag == 'Container' and template.attrib['version'] == '2'
assert template.findtext('Network') == 'bridge'
assert template.findtext('Privileged') == 'false'
configs = {c.attrib['Target']: c for c in template.findall('Config')}
assert configs['8080'].attrib['Type'] == 'Port'
assert configs['/data'].attrib['Type'] == 'Path'
assert all(k in configs for k in ('TZ', 'PUID', 'PGID', 'UMASK'))
for path in Path('.github/workflows').glob('*.yml'):
    for action in re.findall(r'uses:\s*(\S+)', path.read_text()):
        assert action == './.github/workflows/ci.yml' or re.fullmatch(r'[\w-]+/[\w-]+@[0-9a-f]{40}', action), action
print('Version, Unraid structure and action SHA pins validated.')
PY
python3 -m unittest discover -s tests -v
docker compose --env-file .env.example config --quiet
if command -v actionlint >/dev/null; then actionlint; fi
if command -v shellcheck >/dev/null; then shellcheck docker-entrypoint.sh chromium-wrapper scripts/*.sh; fi
