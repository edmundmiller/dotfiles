"""Lifecycle regression with real flock and a detached container-helper stand-in."""

import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest


DISPATCH = Path(__file__).resolve().parents[1] / "config/amp-orbs/dispatch.sh"


class OrbDispatchTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform == 'linux', 'Rootless Podman dispatcher uses Linux flock')
    def test_pause_after_spawn_with_detached_helper(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools = root / "bin"
            tools.mkdir()
            scripts = {
                "id": f"#!{sys.executable}\nprint(1000)\n",
                "df": f"#!{sys.executable}\nprint('Filesystem 1024-blocks Used Available Capacity Mounted\\nfixture 99999999 0 99999999 0% /')\n",
                "podman": f"#!{sys.executable}\n" + """
import os
from pathlib import Path
import subprocess
import sys

root = Path(os.environ['FIXTURE_ROOT'])
args = sys.argv[1:]
if args[0] == 'info':
    print('true' if 'Rootless' in args[-1] else root)
elif args[:2] == ['container', 'exists']:
    pass
elif args[0] == 'inspect':
    print('true')
elif args[0] == 'ps':
    if (root / 'running').exists():
        print(os.environ['ORB_ID'])
elif args[0] == 'start':
    (root / 'running').touch()
    # Mimic a detached Podman helper retaining every inherited descriptor.
    child = subprocess.Popen(['sleep', '30'], close_fds=False,
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    (root / 'helper-pid').write_text(str(child.pid))
elif args[0] == 'stop':
    (root / 'running').unlink()
elif args[0] != 'exec':
    sys.exit('Unexpected fixture command: ' + args[0])
""",
            }
            for name, source in scripts.items():
                path = tools / name
                path.write_text(source)
                path.chmod(0o755)
            environment = dict(
                os.environ,
                PATH=f"{tools}:{os.environ['PATH']}",
                HOME=str(root),
                XDG_STATE_HOME=str(root / 'state'),
                FIXTURE_ROOT=str(root),
                ORB_ID='amp-regression',
                ORB_IMAGE='fixture',
                ORB_TOKEN='non-secret-fixture',
            )
            try:
                subprocess.run(['bash', str(DISPATCH)],
                    env=dict(environment, ORB_OPERATION='spawn'), check=True, timeout=5)
                self.assertTrue((root / 'running').exists())
                pause = subprocess.Popen(['bash', str(DISPATCH)],
                    env=dict(environment, ORB_OPERATION='pause'), start_new_session=True)
                try:
                    pause.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(pause.pid, signal.SIGKILL)
                    pause.wait()
                    self.fail('Pause blocked after spawn while detached helper remained alive')
                self.assertEqual(pause.returncode, 0)
                self.assertFalse((root / 'running').exists())
                os.kill(int((root / 'helper-pid').read_text()), 0)
            finally:
                if (root / 'helper-pid').exists():
                    os.kill(int((root / 'helper-pid').read_text()), signal.SIGTERM)


if __name__ == '__main__':
    unittest.main()
