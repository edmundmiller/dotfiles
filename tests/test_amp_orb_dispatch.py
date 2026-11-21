"""Admission and lifecycle behavior through the dispatcher process interface."""

from array import array
from contextlib import redirect_stdout
import io
import json
from itertools import product
import math
import os
from pathlib import Path
import queue
import re
import runpy
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch


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
            ("resume resizes only stopped target", {"amp-existing": legacy, "amp-test": dict(legacy, running=False)}, required_kib, 8, 20 * 1024 ** 2, True),
            ("rejected resume leaves stopped target intact", {"amp-existing": legacy, "amp-test": dict(legacy, running=False)}, required_kib - 1, 8, 20 * 1024 ** 2, False),
            ("aggregate cap", {"amp-existing": dict(legacy, memory=4 * gib)}, 20 * gib // 1024, 8, 20 * 1024 ** 2, False),
            ("resume legacy with small", {"amp-existing": small, "amp-test": dict(legacy, running=False)}, required_kib, 8, 20 * 1024 ** 2, True),
            ("already running under pressure", {"amp-test": legacy, "amp-existing": small}, 1, 8, 20 * 1024 ** 2, True),
            ("unknown target state", {"amp-test": dict(legacy, running="unknown")}, required_kib, 8, 20 * 1024 ** 2, False),
            ("insufficient CPU headroom", {}, 20 * gib // 1024, 4, 20 * 1024 ** 2, False),
            ("storage short by 1 KiB", {}, 20 * gib // 1024, 8, 20 * 1024 ** 2 - 1, False),
            ("unknown usage", {"amp-existing": dict(legacy, used="unavailable")}, required_kib, 8, 20 * 1024 ** 2, False),
            ("unbounded container", {"amp-existing": dict(legacy, memory=0)}, required_kib, 8, 20 * 1024 ** 2, False),
        ]
        cases = [(2, *case) for case in cases] + [
            (1, "NAS first orb", {}, 4 * gib // 1024, 12, 20 * 1024 ** 2, True),
            (1, "NAS host reserve short by 1 KiB", {}, 4 * gib // 1024 - 1, 12, 20 * 1024 ** 2, False),
            (1, "NAS second orb", {"amp-existing": small}, 20 * gib // 1024, 12, 20 * 1024 ** 2, False),
            (1, "NAS stopped orb resumes", {"amp-test": dict(small, running=False)}, 4 * gib // 1024, 12, 20 * 1024 ** 2, True),
            (1, "NAS second orb resume rejected", {"amp-existing": small, "amp-test": dict(small, running=False)}, 20 * gib // 1024, 12, 20 * 1024 ** 2, False),
            (1, "NAS already running under pressure", {"amp-test": small}, 1, 12, 20 * 1024 ** 2, True),
        ]
        for max_active, name, containers, available, cpus, disk, accepted in cases:
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
elif args[0] in ('create', 'update'):
    memory = args[args.index('--memory') + 1]
    assert memory == args[args.index('--memory-swap') + 1]
    if args[0] == 'update':
        assert not containers[os.environ['ORB_ID']]['running']
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
                        AMP_ORB_MAX_ACTIVE=str(max_active),
                        ORB_OPERATION='spawn', ORB_IMAGE='fixture', ORB_TOKEN='fixture'),
                    capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode == 0, accepted, result.stderr)
                after = json.loads(state.read_text())
                if accepted:
                    self.assertTrue(after['amp-test']['running'])
                    if not containers.get('amp-test', {}).get('running', False):
                        self.assertEqual(after['amp-test']['memory'], 2 * gib)
                        self.assertEqual(after['amp-test']['cpu'], 2000000000)
                    else:
                        self.assertEqual(after['amp-test'], containers['amp-test'])
                    for existing, config in containers.items():
                        if existing != 'amp-test':
                            self.assertEqual(after[existing], config)
                else:
                    self.assertEqual(after, containers)

    @unittest.skipUnless(sys.platform == 'linux', 'Rootless Podman dispatcher uses Linux flock')
    def test_serial_disk_preservation_and_isolation(self):
        # The fake backend models stopped container disks, including ignored
        # content, independently of the dispatcher's snapshot/name choices.
        disk = {'tracked': 'dirty', 'untracked/firmware': 'new', '.amp/ignored': 'evidence'}
        scenarios = ('migrate', 'other orb', 'running', 'mounted', 'absent',
                     'commit failure', 'create failure', 'unplug during create',
                     'interrupted rename', 'fresh target', 'fresh unrelated', 'fresh absent',
                     'missing export')
        for scope, scenario in product(('note4c', 'dji-capture'), scenarios):
            with self.subTest(scope=scope, scenario=scenario), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                tools = root / 'bin'
                tools.mkdir()
                scoped_orb = f'amp-{scope}'
                containers = {
                    scoped_orb: dict(running=scenario == 'running',
                        mounts=int(scenario == 'mounted'), disk=disk),
                    'amp-other': dict(running=True, mounts=0, disk={'other': 'untouched'}),
                }
                fresh = scenario.startswith('fresh')
                target = 'amp-other' if scenario in ('other orb', 'fresh unrelated') else scoped_orb
                if fresh:
                    containers = {}
                state = root / 'containers.json'
                state.write_text(json.dumps(containers))
                scripts = {
                    'id': f'#!{sys.executable}\nprint(1000)\n',
                    'getconf': f'#!{sys.executable}\nprint(8)\n',
                    'df': f"#!{sys.executable}\nprint('fixture 99999999 0 99999999 0% /')\n",
                    'awk': f"#!{sys.executable}\nimport sys\nprint(99999999 if sys.argv[-1] == '/proc/meminfo' else sys.stdin.read().split()[3])\n",
                    'cat': f"#!{sys.executable}\nimport sys\nprint({{'/etc/amp-orbs/note4c-orb': 'amp-note4c', '/etc/amp-orbs/dji-capture-orb': 'amp-dji-capture'}}[sys.argv[1]])\n",
                    'podman': f'#!{sys.executable}\n' + """
import copy, json, os, sys
from pathlib import Path
root = Path(os.environ['FIXTURE_ROOT'])
path = root / 'containers.json'
containers = json.loads(path.read_text())
args = sys.argv[1:]
scenario = os.environ['SCENARIO']
if args[0] == 'info':
    print('true' if 'Rootless' in args[-1] else root)
elif args[:2] == ['container', 'exists']:
    sys.exit(0 if args[-1] in containers else 1)
elif args[0] == 'inspect':
    c = containers[args[-1]]
    template = args[args.index('--format') + 1]
    print('true' if 'Labels' in template else
        str(c['running']).lower() if 'Running' in template else c['mounts'])
elif args[0] == 'commit':
    if scenario == 'commit failure':
        sys.exit(42)
    # Podman rejects uppercase repository names before writing a snapshot.
    repository = args[-1].rsplit(':', 1)[0]
    if repository != repository.lower():
        sys.exit('repository name must be lowercase')
    assert not containers[args[-2]]['running']
    (root / 'snapshot.json').write_text(json.dumps({
        'image': args[-1], 'disk': containers[args[-2]]['disk']}))
    (root / 'committed').touch()
elif args[0] == 'rename':
    assert args[-1] not in containers
    containers[args[-1]] = containers.pop(args[-2])
    if scenario == 'interrupted rename':
        path.write_text(json.dumps(containers))
        sys.exit(42)
elif args[0] == 'create':
    name = args[args.index('--name') + 1]
    snapshot = json.loads((root / 'snapshot.json').read_text()) if not scenario.startswith('fresh') else None
    assert snapshot is None or args[-2] == snapshot['image']
    devices = [args[i+1] for i, arg in enumerate(args) if arg == '--device']
    mounts = [args[i+1] for i, arg in enumerate(args) if arg == '--mount']
    # A bind of the stable directory works without a USB node, but not without
    # the host export itself. --mount must not auto-create a missing host path.
    if mounts and scenario == 'missing export':
        sys.exit(42)
    containers[name] = dict(running=False, mounts=0,
        disk=copy.deepcopy(snapshot['disk']) if snapshot else {'clean': 'base'}, devices=devices, binds=mounts,
        groups=args[args.index('--group-add')+1] if '--group-add' in args else None,
        runtime=args[args.index('--runtime')+1] if '--runtime' in args else None)
    if scenario == 'create failure':
        path.write_text(json.dumps(containers))
        sys.exit(42)
elif args[0] == 'start':
    containers[args[-1]]['running'] = True
elif args[0] not in ('ps', 'exec'):
    sys.exit('Unexpected fixture command: ' + repr(args))
path.write_text(json.dumps(containers))
""",
                }
                for name, source in scripts.items():
                    tool = tools / name
                    tool.write_text(source)
                    tool.chmod(0o755)
                environment = dict(os.environ, PATH=f"{tools}:{os.environ['PATH']}",
                    HOME=str(root), XDG_STATE_HOME=str(root / 'state'),
                    FIXTURE_ROOT=str(root), SCENARIO=scenario, ORB_ID=target,
                    ORB_OPERATION='spawn' if fresh else ('serial-enable' if scope == 'note4c' else 'dji-capture-enable'),
                    ORB_IMAGE='clean-base', ORB_TOKEN='non-secret-fixture')
                result = subprocess.run(['bash', str(DISPATCH)], env=environment,
                    capture_output=True, text=True, timeout=5)
                after = json.loads(state.read_text())
                accepted = scenario in ('migrate', 'fresh target', 'fresh unrelated',
                    'absent', 'fresh absent', 'unplug during create')
                self.assertEqual(result.returncode == 0, accepted, result.stderr)
                if accepted:
                    self.assertEqual(after[target]['devices'], [])
                    self.assertEqual(after[target]['binds'],
                        [] if scenario == 'fresh unrelated' else
                        ['type=bind,src=/dev/amp-note4c-port,dst=/dev/note4c,ro=true'] if scope == 'note4c' else
                        ['type=bind,src=/run/amp-dji-capture,dst=/run/dji-capture,ro=true'])
                    self.assertEqual(after[target]['groups'],
                        None if scenario == 'fresh unrelated' else 'keep-groups')
                    self.assertEqual(after[target]['runtime'],
                        None if scenario == 'fresh unrelated' else 'crun')
                    self.assertEqual(after[target]['running'], fresh)
                    if not fresh:
                        self.assertEqual(after[target]['disk'], disk)
                        backups = [c for name, c in after.items() if name.startswith(f'{scoped_orb}-pre-{scope}-')]
                        self.assertEqual(backups, [containers[target]])
                        self.assertEqual(after['amp-other'], containers['amp-other'])
                elif scenario == 'interrupted rename':
                    self.assertEqual(after['amp-other'], containers['amp-other'])
                    self.assertEqual([c['disk'] for name, c in after.items()
                        if name != 'amp-other'], [disk])
                    wake = subprocess.run(['bash', str(DISPATCH)],
                        env=dict(environment, ORB_OPERATION='spawn'),
                        capture_output=True, text=True, timeout=5)
                    self.assertNotEqual(wake.returncode, 0)
                    self.assertIn('incomplete serial migration' if scope == 'note4c' else
                        'incomplete DJI capture migration', wake.stderr)
                    self.assertEqual(json.loads(state.read_text()), after)
                else:
                    # A failed replacement may be retained, but the original
                    # stopped disk must be restored under the provider's name.
                    for name, original in containers.items():
                        self.assertEqual(after[name], original)
                    if scenario == 'fresh absent':
                        self.assertEqual(after, {})

    def test_dji_capture_identity_excludes_controls_playback_other_ports_and_products(self):
        source = DISPATCH.with_name('dji-capture-broker.py')
        capture_name = runpy.run_path(str(source))['capture_name']
        cases = [
            ('pcmC1D0c', '1-4', '2ca3', '4011', 116, '116:10', True),
            ('pcmC9D0c', '1-4', '2ca3', '4011', 116, '116:10', True),
            ('pcmC1D0p', '1-4', '2ca3', '4011', 116, '116:10', False),
            ('controlC1', '1-4', '2ca3', '4011', 116, '116:10', False),
            ('pcmC1D1c', '1-4', '2ca3', '4011', 116, '116:10', False),
            ('pcmC1D0c', '1-3', '2ca3', '4011', 116, '116:10', False),
            ('pcmC1D0c', '1-4', '303a', '4011', 116, '116:10', False),
            ('pcmC1D0c', '1-4', '2ca3', '831a', 116, '116:10', False),
            ('pcmC1D0c', '1-4', '2ca3', '4011', 166, '166:10', False),
            ('pcmC1D0c', '1-4', '2ca3', '4011', 116, '116:11', False),
        ]
        for name, port, vendor, product_id, major, reported, allowed in cases:
            with self.subTest(name=name, port=port, vendor=vendor, product=product_id, major=major, reported=reported):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    usb = root / f'devices/pci0000:00/0000:00:14.0/usb1/{port}'
                    pcm = usb / f'{port}:1.1/sound/card1/{name}'
                    pcm.mkdir(parents=True)
                    (usb / 'idVendor').write_text(vendor)
                    (usb / 'idProduct').write_text(product_id)
                    (pcm / 'dev').write_text(reported)
                    (root / 'dev/char').mkdir(parents=True)
                    (root / f'dev/char/{major}:10').symlink_to(pcm)
                    if allowed:
                        self.assertEqual(capture_name(root, major, 10), name)
                    else:
                        with self.assertRaises(ValueError):
                            capture_name(root, major, 10)

    def test_dji_capture_open_rejects_replaced_identity_and_closes_rejected_handles(self):
        open_capture = runpy.run_path(str(DISPATCH.with_name('dji-capture-broker.py')))['open_capture']
        real_open, real_fstat = os.open, os.fstat
        for scenario in ('stable', 'wrong device number', 'replaced metadata'):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                usb = root / 'devices/pci0000:00/0000:00:14.0/usb1/1-4'
                pcm = usb / '1-4:1.1/sound/card1/pcmC1D0c'
                pcm.mkdir(parents=True)
                (usb / 'idVendor').write_text('2ca3')
                (usb / 'idProduct').write_text('4011')
                (pcm / 'dev').write_text('116:10')
                (root / 'dev/char').mkdir(parents=True)
                (root / 'dev/char/116:10').symlink_to(pcm)
                (root / 'class/sound').mkdir(parents=True)
                (root / 'class/sound/pcmC1D0c').symlink_to(pcm)
                devices = root / 'audio-fixture'
                devices.mkdir()
                (devices / 'pcmC1D0c').write_text('synthetic, never an audio device')
                opened = []

                def fixture_open(path, flags):
                    fd = real_open(path, flags)
                    if path == devices / 'pcmC1D0c':
                        opened.append(fd)
                        if scenario == 'replaced metadata':
                            pcm.rename(pcm.with_name('removed'))
                            pcm.mkdir()
                            (pcm / 'dev').write_text('116:10')
                    return fd

                def fixture_fstat(fd):
                    if fd in opened:
                        return SimpleNamespace(st_mode=stat.S_IFCHR,
                            st_rdev=os.makedev(116, 11 if scenario == 'wrong device number' else 10))
                    return real_fstat(fd)

                with patch.object(os, 'open', fixture_open), patch.object(os, 'fstat', fixture_fstat):
                    if scenario == 'stable':
                        fd = open_capture(root, devices)
                        os.close(fd)
                    else:
                        with self.assertRaisesRegex(ValueError, 'changed during open'):
                            open_capture(root, devices)
                self.assertEqual(len(opened), 1)
                with self.assertRaises(OSError):
                    real_fstat(opened[0])

    def test_dji_broker_passes_a_handle_not_a_reusable_path(self):
        serve = runpy.run_path(str(DISPATCH.with_name('dji-capture-broker.py')))['serve']
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / 'approved'
            fixture.write_bytes(b'original fixture, not audio')
            server, client = socket.socketpair()
            with server, client, patch.dict(serve.__globals__,
                    open_capture=lambda: os.open(fixture, os.O_RDONLY)):
                client.sendall(b'NOTE4C_DJI_CAPTURE_FD_V1\n')
                serve(server)
                server.close()
                response, ancillary, flags, _ = client.recvmsg(64, socket.CMSG_SPACE(array('i').itemsize))
                self.assertEqual(response, b'OK capture-fd-v1\n')
                self.assertEqual(flags, 0)
                self.assertEqual(len(ancillary), 1)
                level, kind, data = ancillary[0]
                self.assertEqual((level, kind), (socket.SOL_SOCKET, socket.SCM_RIGHTS))
                descriptors = array('i')
                descriptors.frombytes(data)
                try:
                    self.assertEqual(len(descriptors), 1)
                    fixture.unlink()
                    fixture.write_bytes(b'replacement must not be read')
                    self.assertEqual(os.read(descriptors[0], 64), b'original fixture, not audio')
                finally:
                    for fd in descriptors:
                        os.close(fd)

    def test_dji_broker_rejects_caller_selected_targets(self):
        serve = runpy.run_path(str(DISPATCH.with_name('dji-capture-broker.py')))['serve']
        for request in (b'controlC1\n', b'/dev/snd/pcmC0D0p\n', b'NOTE4C_DJI_CAPTURE_FD_V2\n'):
            with self.subTest(request=request):
                server, client = socket.socketpair()
                with server, client, patch.dict(serve.__globals__,
                        open_capture=lambda: self.fail('Rejected request opened hardware')):
                    client.sendall(request)
                    serve(server)
                    self.assertEqual(client.recv(64), b'ERROR request\n')

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


class HeadsetStatusTests(unittest.TestCase):
    def test_readonly_status_tracks_controller_not_card_index_and_keeps_control_indices(self):
        inspect_headset = runpy.run_path(str(DISPATCH.with_name('headset-bench.py')))['inspect_headset']
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pci = root / 'sys/devices/pci0000:00/0000:00:1f.3'
            card = pci / 'sound/card2'
            card.mkdir(parents=True)
            (pci / 'vendor').write_text('0x8086\n')
            (pci / 'device').write_text('0x02c8\n')
            driver = root / 'sys/bus/pci/drivers/snd_hda_intel'
            driver.mkdir(parents=True)
            (pci / 'driver').symlink_to(driver)
            sound = root / 'sys/class/sound'
            sound.mkdir(parents=True)
            (sound / 'card2').symlink_to(card)
            proc = root / 'proc/asound/card2'
            proc.mkdir(parents=True)
            (proc / 'codec#0').write_text('Codec: Realtek ALC256\n')
            for direction, minor in (('c', 3), ('p', 2)):
                pcm = card / f'pcmC2D0{direction}'
                pcm.mkdir()
                (pcm / 'dev').write_text(f'116:{minor}\n')
                (sound / pcm.name).symlink_to(pcm)
                status = proc / f'pcm0{direction}/sub0'
                status.mkdir(parents=True)
                (status / 'status').write_text('closed\n')
            amixer = root / 'amixer'
            amixer.write_text(f'#!{sys.executable}\n' + """
import sys
assert sys.argv[1:3] == ['--card', '2']
if sys.argv[3:] == ['controls']:
    print("numid=1,iface=MIXER,name='Capture Volume'")
    print("numid=2,iface=MIXER,name='Capture Volume',index=1")
    print("numid=3,iface=CARD,name='Headphone Jack'")
    print("numid=4,iface=MIXER,name='IEC958 Playback Default'")
elif sys.argv[3] == 'cget' and sys.argv[4] in ('numid=1', 'numid=2', 'numid=3'):
    print({'numid=1': ': values=0,0', 'numid=2': ': values=17,19',
        'numid=3': ': values=on'}[sys.argv[4]])
else:
    sys.exit('Refusing nonallowlisted read or any write')
""")
            amixer.chmod(0o755)
            result = inspect_headset(root, str(amixer))
            self.assertEqual(result['card_index'], 2)
            self.assertEqual(result['endpoints']['p'],
                {'name': 'pcmC2D0p', 'dev': '116:2', 'status': 'closed'})
            self.assertEqual(result['controls'], {
                '1': {'name': 'Capture Volume', 'index': 0, 'readback': ': values=0,0'},
                '2': {'name': 'Capture Volume', 'index': 1, 'readback': ': values=17,19'},
                '3': {'name': 'Headphone Jack', 'index': 0, 'readback': ': values=on'},
            })
            self.assertFalse(result['pcm_opened'])
            self.assertFalse(result['settings_changed'])
            self.assertFalse(result['acoustic_signal_verified'])
            (pci / 'device').write_text('0x1234\n')
            with self.assertRaisesRegex(ValueError, 'controller'):
                inspect_headset(root, '/must-not-run-on-wrong-controller')

    def test_calibration_restores_asymmetric_baseline_on_success_and_recording_failure(self):
        bench = runpy.run_path(str(DISPATCH.with_name('headset-bench.py')))
        baseline = {
            'Capture Switch': 'on,off', 'Capture Source': '1',
            'Capture Volume': '12,17', 'Headset Mic Boost Volume': '1,2',
            'Master Playback Volume': '31,42', 'Master Playback Switch': 'off,on',
        }
        gains = {
            'Master Playback Volume': (87, '-65.25dB,step=0.75dB'),
            'Capture Volume': (63, '-17.25dB,step=0.75dB'),
            'Headset Mic Boost Volume': (3, '0.00dB,step=10.00dB'),
        }
        unit = (DISPATCH.parents[2] / 'hosts/nuc/amp-orbs.nix').read_text()
        stop_timeout = int(re.search(
            r'note4c-headset-calibration = .*?TimeoutStopSec = (\d+);', unit, re.DOTALL)[1])
        for outcome in ('success', 'recording_failure', 'slow_restore', 'restoration_conflict'):
            with self.subTest(outcome=outcome), tempfile.TemporaryDirectory() as directory:
                state = Path(directory)
                current = dict(baseline)
                recovering = False
                elapsed = 0

                def inspect():
                    nonlocal recovering, elapsed
                    if (state / 'restore.json').exists():
                        recovering = True
                        # The evidenced host has thirteen serial control reads.
                        elapsed += 13 * 0.65
                    controls = {}
                    for number, (name, value) in enumerate(current.items(), 1):
                        text = f': values={value}\n'
                        if name in gains:
                            maximum, scale = gains[name]
                            text += f'; values=2,min=0,max={maximum},step=0\n| dBscale-min={scale}\n'
                        if name == 'Capture Source':
                            text += "; Item #0 'Internal Mic'\n; Item #1 'Internal Mic 1'\n; Item #2 'Headset Mic'\n"
                        controls[str(number)] = {'name': name, 'index': 0, 'readback': text.strip()}
                    controls['12'] = {'name': 'Headphone Jack', 'index': 0, 'readback': ': values=on'}
                    return {'card_index': 3, 'controls': controls,
                        'endpoints': {'c': {'status': 'closed'}, 'p': {'status': 'closed'}}}

                def mixer(card, control, new_value=None):
                    nonlocal elapsed
                    if recovering and outcome == 'slow_restore':
                        elapsed += 0.65
                        if elapsed > stop_timeout:
                            raise TimeoutError('Recovery killed at service stop deadline')
                    self.assertEqual(card, 3)
                    if new_value is not None:
                        current[control['name']] = new_value
                    return current[control['name']]

                def record(card, controls, reference):
                    self.assertEqual(current['Capture Source'], '2')
                    self.assertEqual(current['Capture Switch'], 'on,on')
                    self.assertEqual(len(json.loads((state / 'ledger.json').read_text())), 1)
                    self.assertTrue((state / 'restore.json').exists())
                    if outcome == 'recording_failure':
                        raise ValueError('Recording failed')
                    if outcome == 'restoration_conflict':
                        current['Master Playback Volume'] = '55,55'
                    return {'signal_detected': True}

                with patch.dict(bench['calibrate'].__globals__,
                        inspect_headset=inspect, mixer=mixer, record_tones=record), redirect_stdout(io.StringIO()):
                    if outcome == 'recording_failure':
                        with self.assertRaisesRegex(ValueError, 'Recording failed'):
                            bench['calibrate'](state)
                    elif outcome == 'restoration_conflict':
                        with self.assertRaisesRegex(ValueError, 'Restoration conflict'):
                            bench['calibrate'](state)
                        with self.assertRaisesRegex(ValueError, 'Previous routing restoration unresolved'):
                            bench['calibrate'](state)
                    else:
                        bench['calibrate'](state)
                if outcome == 'restoration_conflict':
                    self.assertEqual(current, dict(baseline, **{'Master Playback Volume': '55,55'}))
                    self.assertTrue((state / 'restore.json').exists())
                    self.assertEqual(len(json.loads((state / 'ledger.json').read_text())), 1)
                    continue
                self.assertEqual(current, baseline)
                self.assertFalse((state / 'restore.json').exists())
                receipt = json.loads((state / 'ledger.json').read_text())[0]
                self.assertEqual(receipt['result'], 'failed' if outcome == 'recording_failure' else 'measured')
                self.assertTrue(receipt['controls_restored'])
                self.assertEqual({path.name for path in state.iterdir()}, {'ledger.json'})

    def test_durable_budget_survives_reload_and_reserves_before_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            for _ in range(10):
                bench = runpy.run_path(str(DISPATCH.with_name('headset-bench.py')))
                bench['claim_trials'](state, 10000, ['headset_calibration'])
            with self.assertRaisesRegex(ValueError, 'budget exhausted'):
                bench['claim_trials'](state, 12099.9, ['headset_calibration'])
            with self.assertRaisesRegex(ValueError, 'backwards'):
                bench['claim_trials'](state, 9999, ['headset_calibration'])
            ledger, trials = bench['claim_trials'](state, 12100, ['headset_calibration'])
            self.assertEqual(len(ledger), 1)
            self.assertEqual(trials[0]['result'], 'reserved')
            for _ in range(8):
                bench['claim_trials'](state, 12100, ['headset_calibration'])
            before = (state / 'ledger.json').read_bytes()
            with self.assertRaisesRegex(ValueError, 'budget exhausted'):
                bench['claim_trials'](state, 12100, ['output', 'input'])
            self.assertEqual((state / 'ledger.json').read_bytes(), before)

    def test_scoring_requires_both_reference_tones_above_background_in_same_channel(self):
        bench = runpy.run_path(str(DISPATCH.with_name('headset-bench.py')))
        rate = 48000
        for case, detected in (('reference', True), ('steady_noise', False),
                ('single_tone', False), ('split_channels', False), ('clipped', False)):
            with self.subTest(case=case):
                samples = array('h')
                for index in range(6 * rate):
                    frequency = 1000 if index < 2 * rate else 2000
                    active = rate <= index < 3 * rate
                    if case == 'steady_noise':
                        active = True
                    if case == 'single_tone':
                        frequency = 1000
                    amplitude = round(1500 * math.sin(2 * math.pi * frequency * index / rate)) if active else 0
                    left = amplitude if case == 'split_channels' and frequency == 1000 else 0
                    right = 0 if case == 'split_channels' and frequency == 1000 else amplitude
                    if case == 'clipped' and index == rate + 100:
                        right = 32767
                    samples.extend((left, right))
                if sys.byteorder != 'little':
                    samples.byteswap()
                result = bench['score'](samples.tobytes())
                self.assertEqual(result['signal_detected'], detected)
                self.assertFalse(result['raw_audio_retained'])
                self.assertFalse(result['intelligibility_verified'])
                self.assertFalse(result['note4c_path_verified'])
        with self.assertRaisesRegex(ValueError, 'Incomplete'):
            bench['score'](b'\0' * 64)

    def test_route_drift_kills_capture_before_waiting_for_collector(self):
        bench = runpy.run_path(str(DISPATCH.with_name('headset-bench.py')))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('arecord', 'aplay'):
                executable = root / name
                executable.write_text(f'#!{sys.executable}\n' + (
                    f'import os, time\nopen({str(root / "pid")!r}, "w").write(str(os.getpid()))\n'
                    'os.write(1, bytes(192000))\ntime.sleep(30)\n' if name == 'arecord' else
                    'import sys\nsys.stdin.buffer.read()\n'))
                executable.chmod(0o755)
            started = time.monotonic()
            with patch.dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH']), \
                    patch.dict(bench['record_tones'].__globals__, mixer=lambda *args: 'wrong source'):
                with self.assertRaisesRegex(ValueError, 'routing changed'):
                    bench['record_tones'](0, {name: {} for name in bench['ROUTE']}, bench['tone']())
            self.assertLess(time.monotonic() - started, 4)
            with self.assertRaises(ProcessLookupError):
                os.kill(int((root / 'pid').read_text()), 0)

    def test_shared_protocol_records_separate_directions_and_restores_on_lost_board_reply(self):
        for lost in (False, True):
            with self.subTest(lost=lost), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                state = root / 'state'
                state.mkdir()
                bench = runpy.run_path(str(DISPATCH.with_name('headset-bench.py')))
                baseline = dict(bench['ROUTE'], **{'Capture Volume': '12,17',
                    'Master Playback Switch': 'off,on', 'Capture Source': '1'})
                current = dict(baseline)
                controls = {name: {'name': name, 'readback': f': values={value}'}
                    for name, value in baseline.items()}
                status = {'card_index': 3, 'endpoints': {'c': {'status': 'closed'}, 'p': {'status': 'closed'}},
                    'controls': {'9': {'name': 'Headphone Jack', 'index': 0, 'readback': ': values=on'}}}
                samples = array('h')
                for index in range(8 * 48000):
                    frequency = 1000 if index < 3 * 48000 else 2000
                    active = 2 * 48000 <= index < 4 * 48000
                    value = round(1200 * math.sin(2 * math.pi * frequency * index / 48000)) if active else 0
                    samples.extend((0, value))
                if sys.byteorder != 'little':
                    samples.byteswap()
                (root / 'fixture').write_bytes(samples.tobytes())
                for tool in ('arecord', 'aplay'):
                    executable = root / tool
                    executable.write_text(f'#!{sys.executable}\nimport sys,time\n' + (
                        f"assert sys.argv[-2:] == ['--duration', '8']\nsys.stdout.buffer.write(open({str(root / 'fixture')!r}, 'rb').read())\n"
                        if tool == 'arecord' else
                        'assert len(sys.stdin.buffer.read()) == 3 * 48000 * 4\ntime.sleep(.4)\n'))
                    executable.chmod(0o755)
                events, incoming = [], queue.Queue()

                class Stream:
                    def write(inner, raw):
                        item = json.loads(raw)
                        events.append(item)
                        if item['event'] == 'reserved':
                            self.assertEqual(len(json.loads((state / 'ledger.json').read_text())), 2)
                            incoming.put({'event': 'board_ready', 'provenance': {'synthetic_fixture': True}})
                        elif item['event'] in ('capture_ready', 'reference_ready'):
                            now = time.monotonic()
                            stages = [{'stage': index, 'pa': int(index in (1, 3)),
                                'samples': 3840, 'rms': 20., 'hz1000': 1., 'hz2000': .1,
                                'clipped': 0} for index in range(5)]
                            if item['event'] == 'reference_ready':
                                stages[0].update(hz1000=200., rms=15.)
                            incoming.put({'event': 'wrong' if lost else 'board_result', 'result': {
                                'trial_id': item['trial_id'], 'stages': stages,
                                'verdict': 'PASS' if item['event'] == 'capture_ready' else 'FAIL',
                                'muted': True, 'command_monotonic': now,
                                'codec_ready_monotonic': now + .001, 'complete_monotonic': now + .002}})
                        elif item['event'] == 'output_measured':
                            incoming.put({'event': 'run_input'})

                    def flush(inner):
                        pass

                    def readline(inner, limit):
                        return json.dumps(incoming.get(timeout=3)).encode() + b'\n'

                def mixer(card, control, new_value=None):
                    if new_value is not None:
                        current[control['name']] = new_value
                    return current[control['name']]

                real_read = Path.read_text
                with patch.dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH']), \
                        patch.object(Path, 'read_text', lambda path, *args, **kwargs:
                            'state: RUNNING' if str(path) == '/proc/asound/card3/pcm0p/sub0/status'
                            else real_read(path, *args, **kwargs)), \
                        patch.dict(bench['independent_paths'].__globals__, inspect_headset=lambda: status,
                            selected_controls=lambda status: controls, mixer=mixer), redirect_stdout(io.StringIO()):
                    if lost:
                        with self.assertRaisesRegex(ValueError, 'Unexpected controller event'):
                            bench['independent_paths'](state, Stream(), SimpleNamespace(settimeout=lambda _: None))
                    else:
                        bench['independent_paths'](state, Stream(), SimpleNamespace(settimeout=lambda _: None))
                self.assertEqual(current, baseline)
                self.assertFalse((state / 'restore.json').exists())
                receipts = json.loads((state / 'ledger.json').read_text())
                self.assertEqual(len(receipts), 2)
                self.assertTrue(all(trial['controls_restored'] for trial in receipts))
                self.assertFalse(any(trial['raw_audio_retained'] for trial in receipts))
                if lost:
                    self.assertNotIn('reference_ready', [event['event'] for event in events])
                    self.assertTrue(all(trial['result'] == 'unknown_or_not_started' for trial in receipts))
                else:
                    self.assertTrue(all(trial['signal_detected'] for trial in receipts))
                    self.assertEqual(receipts[1]['board_result']['verdict'], 'FAIL')
                    self.assertEqual(events[-1]['event'], 'complete')

    def test_input_score_rejects_uncovered_wrong_frequency_and_loud_background(self):
        bench = runpy.run_path(str(DISPATCH.with_name('headset-bench.py')))
        quiet = {'stages': [{'hz1000': 2.}]}
        sample = {'stages': [{'hz1000': 200., 'hz2000': 1., 'rms': 15.}],
            'command_monotonic': 101., 'codec_ready_monotonic': 101.1, 'complete_monotonic': 103.}
        self.assertTrue(bench['input_score'](quiet, sample, {'started': 100., 'ended': 104.})['signal_detected'])
        self.assertFalse(bench['input_score'](quiet, sample, {'started': 100., 'ended': 102.9})['signal_detected'])
        self.assertFalse(bench['input_score']({'stages': [{'hz1000': 20.}]}, sample,
            {'started': 100., 'ended': 104.})['signal_detected'])
        wrong = dict(sample, stages=[{'hz1000': 200., 'hz2000': 60., 'rms': 15.}])
        self.assertFalse(bench['input_score'](quiet, wrong, {'started': 100., 'ended': 104.})['signal_detected'])

    def test_actor_never_replays_unknown_or_expired_commands_or_accepts_stored_results(self):
        actor = runpy.run_path(str(DISPATCH.with_name('shared-controller.py')))
        for case in ('valid', 'expired', 'partial_write', 'reboot', 'stored_result'):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                writes = []

                def write(data):
                    writes.append(data)
                    return 1 if case == 'partial_write' else len(data)

                good = ('NOTE4C selftest: local microphone plus two capped tones; maximum 5s; no saved audio\n'
                    'NOTE4C speaker volume=70 before_dac=0x00 before_mute=0x00 dac=0x2a muted=0\n'
                    'NOTE4C codec reg=0x44 value=0x00\n'
                    + ''.join(f'NOTE4C selftest stage={index} pa={int(index in (1, 3))} samples=3840 rms=15.0 hz1000=200.0 hz2000=1.0 clipped=0\n'
                        for index in range(5))
                    + 'NOTE4C selftest result=PASS; muted; no recording retained\n').encode()
                chunks = [good if case == 'valid' else b'ESP-ROM:esp32s3\n' if case == 'reboot' else
                    b'{"stored":"NOTE4C selftest result=PASS; muted; no recording retained"}\n']

                def read(_):
                    if not chunks:
                        raise TimeoutError('Synthetic serial deadline')
                    return chunks.pop()

                port = SimpleNamespace(write=write, flush=lambda: None, read=read)
                marker = Path(directory) / 'command'
                if case == 'valid':
                    result = actor['selftest'](port, 'a' * 32, time.monotonic() + 1, marker)
                    self.assertEqual(result['result']['verdict'], 'PASS')
                    self.assertEqual(len(result['result']['stages']), 5)
                else:
                    with self.assertRaises(TimeoutError if case == 'stored_result' else ValueError):
                        actor['selftest'](port, 'a' * 32,
                            time.monotonic() + (-1 if case == 'expired' else 1), marker)
                if case != 'expired':
                    with self.assertRaises(FileExistsError):
                        actor['selftest'](port, 'a' * 32, time.monotonic() + 1, marker)
                self.assertEqual(len(writes), 0 if case == 'expired' else 1)


if __name__ == '__main__':
    unittest.main()
