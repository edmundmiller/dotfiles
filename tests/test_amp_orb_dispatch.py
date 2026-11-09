"""Admission and lifecycle behavior through the dispatcher process interface."""

import json
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
    def test_capacity_admission(self):
        gib = 1024 ** 3
        legacy = {"running": True, "memory": 3 * gib, "cpu": 2000000000, "used": gib // 2}
        small = dict(legacy, memory=2 * gib)
        # One legacy orb can still grow by 2.5 GiB. A new 2-GiB orb and
        # 2-GiB host reserve therefore require 6.5 GiB currently available.
        required_kib = 13 * gib // 2 // 1024
        cases = [
            ("second orb", {"amp-existing": legacy}, required_kib, 8, 20 * 1024 ** 2, True),
            ("headroom short by 1 KiB", {"amp-existing": legacy}, required_kib - 1, 8, 20 * 1024 ** 2, False),
            ("third orb", {"amp-one": small, "amp-two": small}, 20 * gib // 1024, 8, 20 * 1024 ** 2, False),
            ("resume exceeds aggregate cap", {"amp-existing": legacy, "amp-test": dict(legacy, running=False)}, 20 * gib // 1024, 8, 20 * 1024 ** 2, False),
            ("resume legacy with small", {"amp-existing": small, "amp-test": dict(legacy, running=False)}, required_kib, 8, 20 * 1024 ** 2, True),
            ("already running under pressure", {"amp-test": legacy, "amp-existing": small}, 1, 8, 20 * 1024 ** 2, True),
            ("insufficient CPU headroom", {}, 20 * gib // 1024, 4, 20 * 1024 ** 2, False),
            ("storage short by 1 KiB", {}, 20 * gib // 1024, 8, 20 * 1024 ** 2 - 1, False),
            ("unknown usage", {"amp-existing": dict(legacy, used="unavailable")}, required_kib, 8, 20 * 1024 ** 2, False),
            ("unbounded container", {"amp-existing": dict(legacy, memory=0)}, required_kib, 8, 20 * 1024 ** 2, False),
        ]
        for name, containers, available, cpus, disk, accepted in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                tools = root / "bin"
                tools.mkdir()
                state = root / "containers.json"
                state.write_text(json.dumps(containers))
                scripts = {
                    "id": f"#!{sys.executable}\nprint(1000)\n",
                    "getconf": f"#!{sys.executable}\nprint({cpus})\n",
                    "df": f"#!{sys.executable}\nprint('Filesystem 1024-blocks Used Available Capacity Mounted\\nfixture 99999999 0 {disk} 0% /')\n",
                    "awk": f"#!{sys.executable}\n" + f"""
import sys
if sys.argv[-1] == '/proc/meminfo':
    print({available})
else:
    print(sys.stdin.read().splitlines()[-1].split()[3])
""",
                    "podman": f"#!{sys.executable}\n" + """
import json, os, sys
from pathlib import Path
root = Path(os.environ['FIXTURE_ROOT'])
path = root / 'containers.json'
containers = json.loads(path.read_text())
args = sys.argv[1:]
if args[0] == 'info':
    print('true' if 'Rootless' in args[-1] else root)
elif args[:2] == ['container', 'exists']:
    sys.exit(0 if args[-1] in containers else 1)
elif args[0] == 'inspect':
    container = containers[args[-1]]
    template = args[args.index('--format') + 1]
    if 'Labels' in template:
        print('true')
    elif 'Running' in template:
        print(str(container['running']).lower())
    else:
        print(container['memory'], container['cpu'])
elif args[0] == 'stats':
    print(containers[args[-1]]['used'])
elif args[0] == 'ps':
    for name, container in containers.items():
        if container['running']:
            print(name)
elif args[0] == 'create':
    memory = args[args.index('--memory') + 1]
    assert memory == args[args.index('--memory-swap') + 1]
    containers[os.environ['ORB_ID']] = dict(running=False,
        memory=int(memory[:-1]) * 1024 ** 3,
        cpu=int(args[args.index('--cpus') + 1]) * 1000000000, used=0)
    path.write_text(json.dumps(containers))
elif args[0] == 'start':
    containers[args[-1]]['running'] = True
    path.write_text(json.dumps(containers))
elif args[0] != 'exec':
    sys.exit('Unexpected fixture command: ' + repr(args))
""",
                }
                for tool, source in scripts.items():
                    path = tools / tool
                    path.write_text(source)
                    path.chmod(0o755)
                result = subprocess.run(['bash', str(DISPATCH)],
                    env=dict(os.environ, PATH=f"{tools}:{os.environ['PATH']}",
                        HOME=str(root), XDG_STATE_HOME=str(root / 'state'),
                        FIXTURE_ROOT=str(root), ORB_ID='amp-test',
                        ORB_OPERATION='spawn', ORB_IMAGE='fixture', ORB_TOKEN='fixture'),
                    capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode == 0, accepted, result.stderr)
                after = json.loads(state.read_text())
                if accepted:
                    self.assertTrue(after['amp-test']['running'])
                    if 'amp-test' not in containers:
                        self.assertEqual(after['amp-test']['memory'], 2 * gib)
                        self.assertEqual(after['amp-test']['cpu'], 2000000000)
                    for existing, config in containers.items():
                        if existing != 'amp-test':
                            self.assertEqual(after[existing], config)
                else:
                    self.assertEqual(after, containers)

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
