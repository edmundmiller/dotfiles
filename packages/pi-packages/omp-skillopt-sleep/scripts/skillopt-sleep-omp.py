#!/usr/bin/env python3
"""OMP thin shell for Microsoft's SkillOpt-Sleep engine.

The upstream SkillOpt-Sleep engine currently harvests Claude Code and Codex
transcripts. OMP sessions are structurally close to Claude Code JSONL, so this
wrapper builds a read-only mirror of OMP transcripts in a Claude-compatible
shape and then delegates to ``python -m skillopt_sleep``.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable

SECRET_PATTERNS = (
    re.compile(r"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*[^\s`'\"]+"),
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"),
)


def redact(text: str) -> str:
    clean = text.replace("\x00", "").strip()
    for pattern in SECRET_PATTERNS:
        clean = pattern.sub("[REDACTED]", clean)
    return clean


def iter_jsonl(path: Path) -> Iterable[dict[str, Any]]:
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(value, dict):
                    yield value
    except (FileNotFoundError, IsADirectoryError, PermissionError):
        return


def text_blocks(content: Any) -> str:
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts: list[str] = []
    for block in content:
        if isinstance(block, str):
            parts.append(block)
        elif isinstance(block, dict) and block.get("type") == "text" and block.get("text"):
            parts.append(str(block["text"]))
    return "\n".join(parts)


def tool_blocks(content: Any) -> list[dict[str, Any]]:
    if not isinstance(content, list):
        return []
    tools: list[dict[str, Any]] = []
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "toolCall" and block.get("name"):
            tools.append({"type": "tool_use", "name": str(block["name"])})
    return tools


def project_slug(cwd: str, fallback: str) -> str:
    if cwd:
        slug = cwd.strip("/").replace("/", "-")
    else:
        slug = fallback
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", slug).strip("-")
    return slug or "unknown-project"


def convert_session(src: Path, dst_root: Path) -> Path | None:
    session_meta: dict[str, str] = {}
    output_records: list[dict[str, Any]] = []

    for rec in iter_jsonl(src):
        rec_type = rec.get("type")
        if rec_type == "session":
            session_meta["cwd"] = str(rec.get("cwd") or "")
            session_meta["sessionId"] = str(rec.get("id") or src.stem)
            session_meta["timestamp"] = str(rec.get("timestamp") or "")
            continue

        if rec_type != "message":
            continue
        message = rec.get("message")
        if not isinstance(message, dict):
            continue
        role = message.get("role")
        if role not in {"user", "assistant"}:
            continue

        timestamp = str(rec.get("timestamp") or message.get("timestamp") or session_meta.get("timestamp") or "")
        content = message.get("content")
        text = redact(text_blocks(content))
        blocks: list[dict[str, Any]] = []
        if text:
            blocks.append({"type": "text", "text": text})
        if role == "assistant":
            blocks.extend(tool_blocks(content))
        if not blocks:
            continue

        output_records.append(
            {
                "type": "message",
                "timestamp": timestamp,
                "cwd": session_meta.get("cwd", ""),
                "sessionId": session_meta.get("sessionId", src.stem),
                "message": {"role": role, "content": blocks},
            }
        )

    if not output_records:
        return None

    dst_dir = dst_root / "projects" / project_slug(session_meta.get("cwd", ""), src.parent.name)
    dst_dir.mkdir(parents=True, exist_ok=True)
    dst = dst_dir / src.name
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return dst
    tmp = dst.with_suffix(dst.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        for record in output_records:
            handle.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")
    os.utime(tmp, (src.stat().st_atime, src.stat().st_mtime))
    tmp.replace(dst)
    return dst


def mirror_omp_sessions(sessions_dir: Path, mirror_home: Path) -> int:
    count = 0
    for src in sessions_dir.rglob("*.jsonl"):
        if src.is_file() and convert_session(src, mirror_home):
            count += 1
    return count


def has_flag(args: list[str], *names: str) -> bool:
    for arg in args:
        for name in names:
            if arg == name or arg.startswith(name + "="):
                return True
    return False


def find_skillopt_repo() -> Path | None:
    candidates: list[Path] = []
    env_repo = os.environ.get("SKILLOPT_SLEEP_REPO")
    if env_repo:
        candidates.append(Path(env_repo).expanduser())
    here = Path(__file__).resolve()
    candidates.extend(here.parents)
    candidates.extend([Path.cwd(), Path.home() / "src" / "SkillOpt", Path.home() / ".skillopt-sleep" / "SkillOpt"])
    for candidate in candidates:
        if (candidate / "skillopt_sleep").is_dir():
            return candidate
    return None


def run_engine(engine_args: list[str]) -> int:
    repo = find_skillopt_repo()
    env = os.environ.copy()
    if repo:
        env["PYTHONPATH"] = str(repo) + (os.pathsep + env["PYTHONPATH"] if env.get("PYTHONPATH") else "")
        cwd = str(repo)
    else:
        cwd = os.getcwd()
    cmd = [os.environ.get("SKILLOPT_SLEEP_PYTHON") or sys.executable, "-m", "skillopt_sleep"] + engine_args
    return subprocess.call(cmd, cwd=cwd, env=env)


def default_engine_args(raw_args: list[str], mirror_home: Path) -> list[str]:
    args = list(raw_args) or ["status"]
    if not has_flag(args, "--claude-home"):
        args.extend(["--claude-home", str(mirror_home)])
    if not has_flag(args, "--source"):
        args.extend(["--source", "claude"])
    if not has_flag(args, "--project"):
        args.extend(["--project", os.getcwd()])
    return args

def strip_schedule_flags(args: list[str]) -> tuple[int, int, list[str], bool]:
    hour = 3
    minute = 17
    all_entries = False
    rest: list[str] = []
    skip_next = False
    for index, arg in enumerate(args):
        if skip_next:
            skip_next = False
            continue
        if arg in {"schedule", "unschedule"}:
            continue
        if arg == "--all":
            all_entries = True
            continue
        if arg == "--hour" and index + 1 < len(args):
            hour = int(args[index + 1])
            skip_next = True
            continue
        if arg.startswith("--hour="):
            hour = int(arg.split("=", 1)[1])
            continue
        if arg == "--minute" and index + 1 < len(args):
            minute = int(args[index + 1])
            skip_next = True
            continue
        if arg.startswith("--minute="):
            minute = int(arg.split("=", 1)[1])
            continue
        rest.append(arg)
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        raise ValueError("--hour must be 0-23 and --minute must be 0-59")
    return hour, minute, rest, all_entries


def crontab_lines() -> list[str]:
    result = subprocess.run(["crontab", "-l"], text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return []
    return result.stdout.splitlines()


def write_crontab(lines: list[str]) -> int:
    payload = "\n".join(lines).rstrip() + ("\n" if lines else "")
    result = subprocess.run(["crontab", "-"], input=payload, text=True, check=False)
    return result.returncode


def schedule_wrapper(raw_args: list[str], sessions_dir: Path, mirror_home: Path) -> int:
    hour, minute, rest, _all_entries = strip_schedule_flags(raw_args)
    marker = f"# skillopt-sleep-omp:{os.getcwd()}"
    script = Path(__file__).resolve()
    log_dir = Path.home() / ".skillopt-sleep" / "omp"
    log_dir.mkdir(parents=True, exist_ok=True)
    env_prefix: list[str] = []
    repo = find_skillopt_repo()
    if repo:
        env_prefix.append(f"SKILLOPT_SLEEP_REPO={shlex.quote(str(repo))}")
    if os.environ.get("SKILLOPT_SLEEP_PYTHON"):
        env_prefix.append(f"SKILLOPT_SLEEP_PYTHON={shlex.quote(os.environ['SKILLOPT_SLEEP_PYTHON'])}")
    command = [
        f"cd {shlex.quote(os.getcwd())}",
        "&&",
        *env_prefix,
        shlex.quote(sys.executable),
        shlex.quote(str(script)),
        "--omp-sessions",
        shlex.quote(str(sessions_dir)),
        "--omp-mirror-home",
        shlex.quote(str(mirror_home)),
        "run",
        *[shlex.quote(arg) for arg in rest],
        ">>",
        shlex.quote(str(log_dir / "nightly.log")),
        "2>&1",
    ]
    cron_line = f"{minute} {hour} * * * {' '.join(command)} {marker}"
    kept = [line for line in crontab_lines() if marker not in line]
    kept.append(cron_line)
    rc = write_crontab(kept)
    if rc == 0:
        print(f"[skillopt-omp] scheduled nightly wrapper at {hour:02d}:{minute:02d} for {os.getcwd()}")
    return rc


def unschedule_wrapper(raw_args: list[str]) -> int:
    _hour, _minute, _rest, all_entries = strip_schedule_flags(raw_args)
    marker_prefix = "# skillopt-sleep-omp:"
    marker = f"{marker_prefix}{os.getcwd()}"
    original = crontab_lines()
    if all_entries:
        kept = [line for line in original if marker_prefix not in line]
    else:
        kept = [line for line in original if marker not in line]
    removed = len(original) - len(kept)
    rc = write_crontab(kept)
    if rc == 0:
        print(f"[skillopt-omp] removed {removed} scheduled entr{'y' if removed == 1 else 'ies'}")
    return rc


def self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        sessions = root / "omp" / "sessions" / "project"
        sessions.mkdir(parents=True)
        src = sessions / "sample.jsonl"
        src.write_text(
            "\n".join(
                [
                    json.dumps({"type": "session", "id": "s1", "timestamp": "2026-01-01T00:00:00Z", "cwd": str(root / "repo")}),
                    json.dumps({"type": "message", "timestamp": "2026-01-01T00:00:01Z", "message": {"role": "user", "content": [{"type": "text", "text": "Fix the failing test"}]}}),
                    json.dumps({"type": "message", "timestamp": "2026-01-01T00:00:02Z", "message": {"role": "assistant", "content": [{"type": "toolCall", "name": "bash", "arguments": {"command": "pytest"}}, {"type": "text", "text": "Done"}]}}),
                    json.dumps({"type": "message", "timestamp": "2026-01-01T00:00:03Z", "message": {"role": "toolResult", "toolName": "bash", "content": [{"type": "text", "text": "secret should not mirror"}]}}),
                ]
            )
            + "\n",
            encoding="utf-8",
        )
        mirror = root / "mirror"
        n = mirror_omp_sessions(sessions.parent.parent / "sessions", mirror)
        out = list((mirror / "projects").rglob("*.jsonl"))
        assert n == 1, n
        assert len(out) == 1, out
        text = out[0].read_text(encoding="utf-8")
        assert "Fix the failing test" in text
        assert '"tool_use"' in text
        assert "secret should not mirror" not in text
    print("skillopt-sleep-omp self-test passed")
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv == ["--self-test"]:
        return self_test()

    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--omp-sessions", default=os.environ.get("OMP_SESSION_DIR", str(Path.home() / ".omp" / "agent" / "sessions")))
    parser.add_argument("--omp-mirror-home", default=os.environ.get("SKILLOPT_SLEEP_OMP_HOME", str(Path.home() / ".skillopt-sleep" / "omp" / "claude-home")))
    parser.add_argument("--help-omp-wrapper", action="store_true")
    known, engine_args = parser.parse_known_args(argv)
    if known.help_omp_wrapper:
        print("Usage: skillopt-sleep-omp.py [--omp-sessions DIR] [--omp-mirror-home DIR] <skillopt_sleep action> [flags]")
        print("Example: skillopt-sleep-omp.py dry-run --backend mock --max-sessions 5 --max-tasks 3 --progress")
        return 0

    sessions_dir = Path(known.omp_sessions).expanduser()
    mirror_home = Path(known.omp_mirror_home).expanduser()
    os.environ.setdefault(
        "SKILLOPT_SLEEP_STAGING_ROOT",
        str(Path.home() / ".skillopt-sleep" / "omp" / "staging"),
    )
    if not sessions_dir.is_dir():
        print(f"[skillopt-omp] ERROR: OMP sessions dir not found: {sessions_dir}", file=sys.stderr)
        return 1
    action = engine_args[0] if engine_args else "status"
    if action == "schedule":
        return schedule_wrapper(engine_args, sessions_dir, mirror_home)
    if action == "unschedule":
        return unschedule_wrapper(engine_args)

    mirrored = mirror_omp_sessions(sessions_dir, mirror_home)
    print(f"[skillopt-omp] mirrored {mirrored} OMP sessions into {mirror_home}", file=sys.stderr)
    return run_engine(default_engine_args(engine_args, mirror_home))


if __name__ == "__main__":
    raise SystemExit(main())
