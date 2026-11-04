"""Exercise studio sync at its CLI boundary without remote or app writes."""

import json
import os
from pathlib import Path
import subprocess
import sys

import pytest


SCRIPT = Path(__file__).resolve().parents[1] / "bin/herdr-studios"


def studio(session, status="running", owner=7):
    return {
        "sessionId": session,
        "name": "Analysis " + session,
        "workspaceId": 42,
        "configuration": {"sshEnabled": True},
        "sshDetails": {"host": "connect.example.invalid", "port": 2222, "user": "studio"},
        "statusInfo": {"status": status},
        "user": {"id": owner, "userName": "researcher"},
    }


@pytest.fixture
def cli(tmp_path):
    bindir = tmp_path / "bin"
    bindir.mkdir()
    home = tmp_path / "home"
    home.mkdir()
    log = tmp_path / "calls.jsonl"
    fake = bindir / "fake"
    fake.write_text(
        f"#!{sys.executable}\n"
        + '''import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\\n")
if name == "op":
    assert args == ["read", "op://Employee/5m7bgfkukzaekmzo5ew2nwmeuq/credential"]
    print("private-test-credential")
elif name == "curl":
    assert sys.stdin.read() == "Authorization: Bearer private-test-credential\\n"
    url = args[-1]
    if os.environ.get("FAIL_API") and "/studios?" in url:
        print("upstream unavailable", file=sys.stderr)
        sys.exit(22)
    if url.endswith("/user-info"):
        print('{"user":{"id":7}}')
    elif url.endswith("/user/7/workspaces"):
        print('{"orgsAndWorkspaces":[{"workspaceId":42,"orgName":"Org","workspaceName":"Lab"}]}')
    elif "/studios?workspaceId=42&max=100&offset=0" in url:
        print(json.dumps({"studios": json.loads(os.environ["STUDIOS"])}))
    else:
        sys.exit("unexpected URL: " + url)
elif name == "hc":
    if args == ["machine", "ls", "--json"]:
        if os.environ.get("FAIL_LS"):
            sys.exit("core unavailable")
        print(os.environ["SAVED"])
    elif args[:2] == ["machine", "add"]:
        if os.environ.get("FAIL_ADD"):
            sys.exit("unknown core failure")
    else:
        sys.exit("unexpected hc operation")
elif name == "uname":
    print(os.environ.get("TEST_SYSTEM", "Darwin"))
elif name == "herdr":
    if args == ["--version"]:
        print("herdr 1.2.3")
    elif args == ["machine", "list", "--json"]:
        print('[]')
    elif args[:2] != ["machine", "add"]:
        sys.exit("unexpected legacy operation")
else:
    sys.exit("forbidden command: " + name)
'''
    )
    fake.chmod(0o755)
    for name in ("op", "curl", "hc", "herdr", "ssh", "uname"):
        (bindir / name).symlink_to(fake)
    env = {
        **os.environ,
        "HOME": str(home),
        "PATH": str(bindir) + os.pathsep + os.environ["PATH"],
        "CALL_LOG": str(log),
        "HERDR_BACKEND": "native",
        "HERDR_STUDIOS_SSH_CONFIG": str(home / ".ssh/seqera-studios.conf"),
        "TOWER_ACCESS_TOKEN": "",
        "SEQERA_ACCESS_TOKEN": "",
    }

    def invoke(studios, saved=None, flags=(), **extra):
        log.write_text("")
        result = subprocess.run(
            ["bash", str(SCRIPT), "sync", *flags],
            env={**env, "STUDIOS": json.dumps(studios),
                 "SAVED": json.dumps({"machines": saved or []}), **extra},
            capture_output=True, text=True,
        )
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        assert "private-test-credential" not in result.stdout + result.stderr
        assert "private-test-credential" not in log.read_text()
        return result, calls

    return home, invoke


def test_native_installs_using_stable_alias_and_writes_ssh_config(cli):
    home, invoke = cli
    result, calls = invoke([studio("91")])
    assert result.returncode == 0, result.stderr
    assert [c for c in calls if c[0] == "hc"] == [
        ["hc", "machine", "ls", "--json"],
        ["hc", "machine", "add", "--install", "--name", "seqera-studio-a91", "seqera-studio-a91"],
    ]
    assert not any(c[0] in ("herdr", "ssh") for c in calls)
    config = home / ".ssh/seqera-studios.conf"
    assert "Host seqera-studio-a91\n    HostName connect.example.invalid\n    Port 2222\n    User studio" in config.read_text()
    assert config.stat().st_mode & 0o777 == 0o600
    assert (home / ".ssh/config").read_text() == f"Include {config}\n"


def test_dry_run_has_no_local_or_remote_writes(cli):
    home, invoke = cli
    result, calls = invoke([studio("91")], flags=("--dry-run",))
    assert result.returncode == 0, result.stderr
    assert not (home / ".ssh").exists()
    assert [c for c in calls if c[0] == "hc"] == [["hc", "machine", "ls", "--json"]]
    assert not any(c[0] in ("herdr", "ssh") for c in calls)
    assert "+ hc machine add --install --name seqera-studio-a91 seqera-studio-a91" in result.stdout


def test_preserves_stopped_filtered_deleted_and_core_profiles(cli):
    home, invoke = cli
    ssh_dir = home / ".ssh"
    ssh_dir.mkdir()
    config = ssh_dir / "seqera-studios.conf"
    preserved = "Host seqera-studio-a93\n    HostName old.example.invalid\n"
    config.write_text(preserved)
    saved = [
        {"name": "existing-core", "target": "seqera-studio-a91", "temporary": False},
        {"name": "seqera-studio-a92", "target": "seqera-studio-a92", "temporary": True},
        {"name": "seqera-studio-a93", "target": "seqera-studio-a93"},
        {"name": "seqera-studio-a94", "target": "seqera-studio-a94"},
        {"name": "production", "target": "prod"},
    ]
    result, calls = invoke([studio("91"), studio("92", "stopped"), studio("93", owner=8)], saved)
    assert result.returncode == 0, result.stderr
    assert [c for c in calls if c[0] == "hc"] == [["hc", "machine", "ls", "--json"]]
    assert preserved in config.read_text()
    assert "skipped seqera-studio-a92 (stopped)" in result.stdout
    assert "skipped seqera-studio-a93 (deleted, filtered, or not visible)" in result.stdout
    assert "skipped seqera-studio-a94 (deleted, filtered, or not visible)" in result.stdout


def test_all_users_includes_other_owner(cli):
    _, invoke = cli
    result, calls = invoke([studio("93", owner=8)], flags=("--all-users",))
    assert result.returncode == 0, result.stderr
    assert ["hc", "machine", "add", "--install", "--name", "seqera-studio-a93", "seqera-studio-a93"] in calls


@pytest.mark.parametrize("failure,message", [
    ("FAIL_ADD", "unknown core failure"),
    ("FAIL_LS", "core unavailable"),
    ("FAIL_API", "upstream unavailable"),
])
def test_unknown_failures_are_not_silently_ignored(cli, failure, message):
    home, invoke = cli
    result, calls = invoke([studio("91")], **{failure: "1"})
    assert result.returncode != 0
    assert message in result.stderr
    if failure == "FAIL_API":
        assert not (home / ".ssh").exists()
        assert not any(c[0] == "hc" for c in calls)


@pytest.mark.parametrize("system", ["Darwin", "Linux"])
def test_platform_default_registers_core_machines(cli, system):
    home, invoke = cli
    result, calls = invoke([studio("91")], HERDR_BACKEND="", TEST_SYSTEM=system)
    assert result.returncode == 0, result.stderr
    assert "Host seqera-studio-a91" in (home / ".ssh/seqera-studios.conf").read_text()
    assert ["hc", "machine", "ls", "--json"] in calls
    assert any(c[:3] == ["hc", "machine", "add"] for c in calls)
    assert not any(c[0] == "herdr" for c in calls)


def test_explicit_legacy_retains_legacy_dry_run(cli):
    home, invoke = cli
    result, calls = invoke([studio("91")], flags=("--dry-run",), HERDR_BACKEND="legacy")
    assert result.returncode == 0, result.stderr
    assert ["herdr", "machine", "list", "--json"] in calls
    assert "+ install_remote seqera-studio-a91" in result.stdout
    assert "+ add_machine Analysis 91 seqera-studio-a91" in result.stdout
    assert not (home / ".ssh").exists()
    assert not any(c[0] in ("hc", "ssh") for c in calls)


def test_existing_name_collision_is_preserved(cli):
    _, invoke = cli
    result, calls = invoke([studio("91")], [{"name": "seqera-studio-a91", "target": "custom-core"}])
    assert result.returncode == 0, result.stderr
    assert [c for c in calls if c[0] == "hc"] == [["hc", "machine", "ls", "--json"]]


@pytest.mark.parametrize("reply", ['{}', '{"machines":null}', '{"machines":[{"id":1}]}', 'not json'])
def test_invalid_core_schema_fails_without_remote_writes(cli, reply):
    _, invoke = cli
    result, calls = invoke([studio("91")], SAVED=reply)
    assert result.returncode != 0
    assert "herdr-studios: invalid hc machine ls response" in result.stderr
    assert [c for c in calls if c[0] == "hc"] == [["hc", "machine", "ls", "--json"]]
