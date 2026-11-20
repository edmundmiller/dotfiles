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

def pop_exit(env_name):
    path = os.environ.get(env_name)
    if not path or not Path(path).exists():
        return
    codes = Path(path).read_text().split()
    if not codes:
        return
    code = int(codes.pop(0))
    Path(path).write_text(" ".join(codes))
    sys.exit(code)

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
elif name == "ssh":
    pop_exit("SSH_EXIT_FILE")
elif name == "rex":
    if args[:2] != ["server", "install"] or not args[2].startswith("ssh://"):
        sys.exit("unexpected rex operation")
    pop_exit("REX_EXIT_FILE")
else:
    sys.exit("forbidden command: " + name)
'''
    )
    fake.chmod(0o755)
    for name in ("op", "curl", "hc", "herdr", "ssh", "uname", "rex"):
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

    def invoke(studios, saved=None, flags=(), command="sync", **extra):
        log.write_text("")
        result = subprocess.run(
            ["bash", str(SCRIPT), command, *flags],
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


def reads(calls):
    return [c[-1] for c in calls if c[0] == "curl"]


def test_help_exits_before_the_api(cli):
    _, invoke = cli
    result, calls = invoke([], command="--help")
    assert result.returncode == 0, result.stderr
    assert "herdr-studios rex <alias-or-session>" in result.stderr
    assert "does not start, stop, or delete" in result.stderr
    assert calls == []

    rejected, rejected_calls = invoke([], command="sync", flags=("seqera-studio-a91",))
    assert rejected.returncode != 0
    assert rejected_calls == []


def test_rex_dry_run_prints_install_without_ssh(cli):
    _, invoke = cli
    result, calls = invoke([studio("91")], command="rex", flags=("--dry-run", "91"))
    assert result.returncode == 0, result.stderr
    assert "+ ssh -o BatchMode=yes seqera-studio-a91" in result.stdout
    assert "XDG_RUNTIME_DIR" in result.stdout
    assert "mkdir -p" in result.stdout
    assert "sudo" not in result.stdout
    assert "+ rex server install ssh://seqera-studio-a91" in result.stdout
    assert result.stdout.rstrip().splitlines()[-1] == "ssh://seqera-studio-a91"
    assert not any(c[0] in ("ssh", "rex", "hc", "herdr") for c in calls)
    assert reads(calls) == [
        "https://api.cloud.seqera.io/user-info",
        "https://api.cloud.seqera.io/user/7/workspaces",
        "https://api.cloud.seqera.io/studios?workspaceId=42&max=100&offset=0",
    ]


def test_rex_installs_by_alias_and_again_after_restart(cli):
    _, invoke = cli
    for _ in range(2):
        result, calls = invoke([studio("91")], command="rex", flags=("seqera-studio-a91",))
        assert result.returncode == 0, result.stderr
        ssh = [c for c in calls if c[0] == "ssh"]
        assert len(ssh) == 1
        assert ssh[0][1:4] == ["-o", "BatchMode=yes", "seqera-studio-a91"]
        assert "mkdir -p" in ssh[0][4] and "/run/user/" in ssh[0][4]
        assert [c for c in calls if c[0] == "rex"] == [
            ["rex", "server", "install", "ssh://seqera-studio-a91"],
        ]
        assert result.stdout.rstrip().splitlines()[-1] == "ssh://seqera-studio-a91"
        assert not any(c[0] in ("hc", "herdr") for c in calls)


def test_rex_retries_only_ssh_exit_255(cli, tmp_path):
    _, invoke = cli
    ssh_exits = tmp_path / "ssh-exits"
    rex_exits = tmp_path / "rex-exits"
    ssh_exits.write_text("255 255 0")
    result, calls = invoke(
        [studio("91")], command="rex", flags=("91",), SSH_EXIT_FILE=str(ssh_exits),
    )
    assert result.returncode == 0, result.stderr
    assert len([c for c in calls if c[0] == "ssh"]) == 3
    assert [c for c in calls if c[0] == "rex"] == [
        ["rex", "server", "install", "ssh://seqera-studio-a91"],
    ]
    assert result.stderr.count("after ssh exit 255") == 2

    rex_exits.write_text("255 0")
    result, calls = invoke(
        [studio("91")], command="rex", flags=("91",), REX_EXIT_FILE=str(rex_exits),
    )
    assert result.returncode == 0, result.stderr
    assert len([c for c in calls if c[0] == "ssh"]) == 1
    assert len([c for c in calls if c[0] == "rex"]) == 2

    ssh_exits.write_text("1")
    result, calls = invoke(
        [studio("91")], command="rex", flags=("91",), SSH_EXIT_FILE=str(ssh_exits),
    )
    assert result.returncode == 1
    assert len([c for c in calls if c[0] == "ssh"]) == 1
    assert not any(c[0] == "rex" for c in calls)
    assert "retrying" not in result.stderr

    rex_exits.write_text("2")
    result, calls = invoke(
        [studio("91")], command="rex", flags=("91",), REX_EXIT_FILE=str(rex_exits),
    )
    assert result.returncode == 2
    assert len([c for c in calls if c[0] == "rex"]) == 1
    assert "retrying" not in result.stderr

    ssh_exits.write_text("255 255 255")
    result, calls = invoke(
        [studio("91")], command="rex", flags=("91",), SSH_EXIT_FILE=str(ssh_exits),
    )
    assert result.returncode == 255
    assert len([c for c in calls if c[0] == "ssh"]) == 3
    assert not any(c[0] == "rex" for c in calls)
    assert result.stderr.count("after ssh exit 255") == 2


def test_rex_refuses_stopped_and_other_owners_without_ssh(cli):
    _, invoke = cli
    stopped, stopped_calls = invoke([studio("91", "stopped")], command="rex", flags=("91",))
    assert stopped.returncode != 0
    assert "no running studio matches 91" in stopped.stderr
    assert not any(c[0] in ("ssh", "rex") for c in stopped_calls)

    other, other_calls = invoke([studio("91", owner=8)], command="rex", flags=("91",))
    assert other.returncode != 0
    assert not any(c[0] in ("ssh", "rex") for c in other_calls)

    allowed, allowed_calls = invoke(
        [studio("91", owner=8)], command="rex", flags=("--all-users", "91"),
    )
    assert allowed.returncode == 0, allowed.stderr
    assert ["rex", "server", "install", "ssh://seqera-studio-a91"] in allowed_calls
