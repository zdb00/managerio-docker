"""Daemon-free regression tests for update decisions and smoke-test cleanup."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        (self.root / 'bin').mkdir()
        for name in ('check-upstream.sh', 'smoke-test.sh'):
            shutil.copy(ROOT / 'scripts' / name, self.root / 'scripts' / name)
        self.env = dict(os.environ, PATH=str(self.root / 'bin') + ':' + os.environ['PATH'])
        self.env.pop('GITHUB_OUTPUT', None)
        self.env.pop('GH_TOKEN', None)

    def shim(self, name, code):
        path = self.root / 'bin' / name
        path.write_text('#!/usr/bin/env python3\n' + code)
        path.chmod(0o755)

    def upstream(self, current, latest, digest=True):
        (self.root / 'MANAGER_VERSION').write_text(current + '\n')
        data = dict(tag_name=latest, draft=False, prerelease=False, assets=[
            dict(name=f'ManagerServer-linux-{arch}.tar.gz', digest='sha256:' + 'a' * 64 if digest else None)
            for arch in ('x64', 'arm64')])
        self.env['RELEASE_DATA'] = json.dumps(data)
        self.shim('curl', "import os,sys\nfrom pathlib import Path\nPath(sys.argv[sys.argv.index('-o')+1]).write_text(os.environ['RELEASE_DATA'])\n")
        return subprocess.run(['bash', str(self.root / 'scripts/check-upstream.sh'), '--update'],
                              env=self.env, capture_output=True, text=True)

    def test_numeric_update(self):
        self.assertEqual(self.upstream('26.9.1.1', '26.10.1.1').returncode, 0)
        self.assertEqual((self.root / 'MANAGER_VERSION').read_text(), '26.10.1.1\n')

    def test_equal_or_older_does_not_update(self):
        for latest in ('26.10.1.1', '26.9.1.1'):
            self.assertEqual(self.upstream('26.10.1.1', latest).returncode, 0)
            self.assertEqual((self.root / 'MANAGER_VERSION').read_text(), '26.10.1.1\n')

    def test_missing_digest_or_invalid_version_rejected(self):
        for latest, digest in [('26.10.1.1', False), ('v26.10.1.1', True), ('26.10.1.1\nmalicious', True)]:
            self.assertNotEqual(self.upstream('26.9.1.1', latest, digest).returncode, 0)
            self.assertEqual((self.root / 'MANAGER_VERSION').read_text(), '26.9.1.1\n')

    def smoke(self, mode):
        log = self.root / 'calls.jsonl'
        self.env.update(CALL_LOG=str(log), TEST_MODE=mode, SMOKE_TIMEOUT='1')
        self.shim('docker', '''import json,os,sys
args=sys.argv[1:]
with open(os.environ['CALL_LOG'],'a') as f: f.write(json.dumps(args)+'\\n')
if args[:2]==['volume','create']: print('test-volume')
elif args[0]=='run': print('test-container')
elif args[0]=='port': print('127.0.0.1:45678')
elif args[0]=='inspect':
    if 'ExitCode' in args[2]: print('137' if os.environ['TEST_MODE']=='forced-kill' else '0')
    else: print('false' if os.environ['TEST_MODE']=='crash' else 'true')
''')
        self.shim('curl', "import os,sys\nsys.exit(1 if os.environ['TEST_MODE'] in ('crash','timeout') else 0)\n")
        result = subprocess.run(['bash', str(self.root / 'scripts/smoke-test.sh'), 'fake-image'],
                                env=self.env, capture_output=True, text=True, timeout=15)
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertIn(['rm', '-f', '-v', 'test-container'], calls)
        self.assertIn(['volume', 'rm', 'test-volume'], calls)
        return result, calls

    def test_smoke_success_recreates_and_cleans(self):
        result, calls = self.smoke('success')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(c[0] == 'run' for c in calls), 2)

    def test_smoke_failure_logs_and_cleans(self):
        for mode in ('crash', 'timeout', 'forced-kill'):
            with self.subTest(mode=mode):
                result, calls = self.smoke(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(['logs', 'test-container'], calls)

    def test_downloader_rejects_bad_input_before_network(self):
        for version, arch in [('latest', 'amd64'), ('26.8.4.3664', 'riscv64')]:
            result = subprocess.run(['bash', str(ROOT / 'scripts/download-manager.sh')],
                                    env=dict(self.env, MANAGER_VERSION=version, TARGETARCH=arch),
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue('Invalid Manager version' in result.stderr or 'Unsupported TARGETARCH' in result.stderr)


if __name__ == '__main__':
    unittest.main()
