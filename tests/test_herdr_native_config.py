"""Native Herdr activation preserves application-owned data and unrelated preferences."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "config/herdr/native/reconcile-config.py"


def reconcile(home, source):
    return subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--home",
            str(home),
            "--source",
            str(source),
            "--core",
            "/test/bin/hc",
        ],
        text=True,
        capture_output=True,
    )


@pytest.fixture
def native_config(tmp_path):
    source = tmp_path / "source"
    source.mkdir()
    for name, value in {
        "settings.json": {"sounds": {"enabled": False}},
        "keys.json": {"global": {"cmd-shift-g": "mod.open:dotfiles-dev"}},
        "programs.json": {"programs": {"omp": {"run": ["omp"]}}},
    }.items():
        (source / name).write_text(json.dumps(value))
    return tmp_path / "app", source


def test_native_reconciliation_preserves_preferences_and_state(native_config):
    home, source = native_config
    home.mkdir()
    (home / "settings.json").write_text(
        json.dumps(
            {
                "zoom": 1.5,
                "sounds": {"enabled": True, "done": "mine.mp3"},
                "theme": "moss",
            }
        )
    )
    (home / "keys.json").write_text(
        json.dumps(
            {
                "terminal": {"ctrl-1": "terminal"},
                "global": {"cmd-p": "mod.open:picker"},
            }
        )
    )
    (home / "programs.json").write_text(
        json.dumps(
            {
                "programs": {"omp": {"icon": "mine.svg"}, "custom": {"name": "Mine"}},
            }
        )
    )
    untouched = {
        "shared.json": b'{"layout":"mine"}',
        "view.json": b'{"tab":"t7"}',
        "layouts/.state/main.json": b'{"width":123}',
        "layouts/main.json": b'{"shipped":true}',
        "AGENTS.md": b"generated instructions",
    }
    for name, content in untouched.items():
        target = home / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    result = reconcile(home, source)
    assert result.returncode == 0, result.stderr
    assert json.loads((home / "settings.json").read_text()) == {
        "zoom": 1.5,
        "sounds": {"enabled": False, "done": "mine.mp3"},
        "theme": "moss",
        "core": "/test/bin/hc",
    }
    assert json.loads((home / "keys.json").read_text()) == {
        "terminal": {"ctrl-1": "terminal"},
        "global": {"cmd-p": "mod.open:picker", "cmd-shift-g": "mod.open:dotfiles-dev"},
    }
    assert json.loads((home / "programs.json").read_text()) == {
        "programs": {
            "omp": {"icon": "mine.svg", "run": ["omp"]},
            "custom": {"name": "Mine"},
        },
    }
    assert {name: (home / name).read_bytes() for name in untouched} == untouched
    snapshots = {
        name: ((home / name).read_bytes(), (home / name).stat().st_mtime_ns)
        for name in ("settings.json", "keys.json", "programs.json")
    }
    assert reconcile(home, source).returncode == 0
    assert {
        name: ((home / name).read_bytes(), (home / name).stat().st_mtime_ns)
        for name in snapshots
    } == snapshots


@pytest.mark.parametrize("invalid", ["{broken", "[]", '{"global": "invalid"}'])
def test_invalid_preferences_fail_before_any_write(native_config, invalid):
    home, source = native_config
    home.mkdir()
    original_settings = b'{"zoom":2}'
    (home / "settings.json").write_bytes(original_settings)
    (home / "keys.json").write_text(invalid)
    result = reconcile(home, source)
    assert result.returncode != 0
    assert (home / "settings.json").read_bytes() == original_settings
    assert (home / "keys.json").read_text() == invalid
    assert not (home / "programs.json").exists()


def test_store_symlink_becomes_writable_without_changing_store_target(
    native_config, tmp_path
):
    home, source = native_config
    home.mkdir()
    store = tmp_path / "store.json"
    store.write_text('{"zoom":2}')
    store.chmod(0o444)
    (home / "settings.json").symlink_to(store)
    result = reconcile(home, source)
    assert result.returncode == 0, result.stderr
    assert not (home / "settings.json").is_symlink()
    assert (home / "settings.json").stat().st_mode & 0o200
    assert store.read_text() == '{"zoom":2}'


def test_template_changes_are_reapplied(native_config):
    home, source = native_config
    assert reconcile(home, source).returncode == 0
    (source / "settings.json").write_text('{"sounds":{"enabled":true}}')
    assert reconcile(home, source).returncode == 0
    assert json.loads((home / "settings.json").read_text())["sounds"]["enabled"] is True


@pytest.mark.parametrize("damage", ["missing", "invalid"])
def test_bad_template_fails_without_creating_preferences(native_config, damage):
    home, source = native_config
    template = source / "keys.json"
    if damage == "missing":
        template.unlink()
    else:
        template.write_text("[broken")
    result = reconcile(home, source)
    assert result.returncode != 0
    assert not home.exists()


@pytest.mark.parametrize(
    "backend,args,expected",
    [
        ("native", [], ["hc", "run", "--on", "nuc"]),
        ("native", ["t7", "--observe"], ["hc", "attach", "nuc/t7", "--observe"]),
        ("legacy", [], ["herdr", "--remote", "nuc"]),
        ("legacy", ["--help"], ["herdr", "--remote", "nuc", "--help"]),
    ],
)
def test_nuc_alias_routes_to_selected_backend(tmp_path, backend, args, expected):
    zsh = shutil.which("zsh")
    assert zsh is not None, "zsh is required to check the deployed alias"
    for name in ("hc", "herdr"):
        executable = tmp_path / name
        executable.write_text(f'#!/bin/sh\nprintf "%s\\n" {name} "$@"\n')
        executable.chmod(0o755)
    result = subprocess.run(
        [
            zsh,
            "-f",
            "-c",
            'source "$1"; shift; hnuc "$@"',
            "alias-test",
            str(ROOT / "config/herdr/aliases.zsh"),
            *args,
        ],
        env={**os.environ, "HERDR_BACKEND": backend, "PATH": str(tmp_path)},
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == expected


@pytest.fixture
def machine_registry(tmp_path):
    """A persistent CLI fake; rejects duplicate names and unavailable targets."""
    registry = tmp_path / "machines.json"
    registry.write_text(
        json.dumps(
            {
                "machines": [
                    {
                        "name": "studio",
                        "target": "user@studio",
                        "session": None,
                        "via": False,
                        "temporary": True,
                        "state": "disconnected",
                    }
                ]
            }
        )
    )
    core = tmp_path / "hc"
    core.write_text(
        f"#!{sys.executable}\n"
        "import argparse, json, pathlib, sys\n"
        f"registry = pathlib.Path({str(registry)!r})\n"
        "parser = argparse.ArgumentParser()\n"
        "parser.add_argument('--json', action='store_true')\n"
        "parser.add_argument('command', choices=['machine'])\n"
        "parser.add_argument('action', choices=['ls', 'add'])\n"
        "parser.add_argument('--name')\n"
        "parser.add_argument('target', nargs='?')\n"
        "args = parser.parse_args()\n"
        "data = json.loads(registry.read_text())\n"
        "if args.action == 'add':\n"
        "    if args.target == 'offline': sys.exit('unreachable')\n"
        "    if any(m['name'] == args.name for m in data['machines']):\n"
        "        sys.exit('name_taken')\n"
        "    data['machines'].append(dict(name=args.name, target=args.target,\n"
        "        session=None, via=False, temporary=False, state='disconnected'))\n"
        "    registry.write_text(json.dumps(data))\n"
        "print(json.dumps(data))\n"
    )
    core.chmod(0o755)

    def register(machines):
        desired = tmp_path / "desired.json"
        desired.write_text(json.dumps(machines))
        return subprocess.run(
            [
                sys.executable,
                str(ROOT / "config/herdr/native/reconcile-machines.py"),
                "--core",
                str(core),
                "--machines",
                str(desired),
            ],
            capture_output=True,
            text=True,
        )

    return registry, register


def test_machine_registration_is_additive_and_idempotent(machine_registry):
    registry, register = machine_registry
    studio = json.loads(registry.read_text())["machines"][0]
    result = register({"nuc": "emiller@nuc"})
    assert result.returncode == 0, result.stderr
    assert json.loads(registry.read_text())["machines"] == [
        studio,
        {
            "name": "nuc",
            "target": "emiller@nuc",
            "session": None,
            "via": False,
            "temporary": False,
            "state": "disconnected",
        },
    ]
    snapshot = registry.read_bytes(), registry.stat().st_mtime_ns
    assert register({"nuc": "emiller@nuc"}).returncode == 0
    assert register({}).returncode == 0
    assert (registry.read_bytes(), registry.stat().st_mtime_ns) == snapshot


@pytest.mark.parametrize(
    "target,temporary", [("different-host", False), ("user@studio", True)]
)
def test_machine_conflict_refuses_changes_before_adding_anything(
    machine_registry, target, temporary
):
    registry, register = machine_registry
    machines = json.loads(registry.read_text())
    machines["machines"][0]["temporary"] = temporary
    registry.write_text(json.dumps(machines))
    before = registry.read_bytes()
    # Even with the same target, a temporary connection cannot satisfy a
    # declared permanent machine. A missing entry first must not be added.
    result = register({"nuc": "emiller@nuc", "studio": target})
    assert result.returncode != 0
    assert "conflicts with declared SSH target" in result.stderr
    assert registry.read_bytes() == before


def test_unreachable_machine_reports_failure_without_changing_registry(
    machine_registry,
):
    registry, register = machine_registry
    before = registry.read_bytes()
    result = register({"nuc": "offline"})
    assert result.returncode != 0
    assert "unreachable" in result.stderr
    assert registry.read_bytes() == before
