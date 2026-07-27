from __future__ import annotations

import json
import os
import shutil
import sqlite3
import subprocess
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Callable, Iterable, Iterator


Normalize = Callable[[bytes], object]


@dataclass(frozen=True)
class Candidate:
    source: str
    native_id: str
    native_format: str
    native_locator: str
    native_modified_at: datetime
    native_size: int
    read: Callable[[], bytes]
    normalize: Normalize
    started_at: datetime | None = None
    updated_at: datetime | None = None
    title: str | None = None
    cwd: str | None = None
    model: str | None = None


@dataclass(frozen=True)
class FileRoot:
    label: str
    adapter: str
    root: str
    pattern: str = "*.jsonl"


FILE_ROOTS = (
    FileRoot("codex", "codex", "~/.codex/sessions"),
    FileRoot("codex-archived", "codex", "~/.codex/archived_sessions"),
    FileRoot("claude-code", "claude-code", "~/.claude/projects"),
    FileRoot("openclaw", "openclaw", "~/.openclaw/agents/*/sessions"),
    FileRoot("omp", "openclaw", "~/.omp/agent/sessions"),
    FileRoot("pi", "openclaw", "~/.pi/agent/sessions"),
    FileRoot("letta-code", "letta-code", "~/.letta/transcripts"),
    FileRoot("openhands", "openhands", "~/.openhands/sessions"),
)


def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()


def stable_read(path: Path) -> bytes:
    for attempt in range(2):
        before = os.stat(path)
        data = path.read_bytes()
        after = os.stat(path)
        if (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns):
            return data
        if attempt:
            break
    raise RuntimeError(f"source changed while reading: {home_relative(path)}")


def home_relative(path: Path) -> str:
    home = Path.home()
    try:
        return f"~/{path.resolve().relative_to(home.resolve())}"
    except ValueError:
        return str(path)


def _parse_time(value: object) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        # Hermes uses seconds; OpenCode uses ms. Prefer seconds when value is small.
        seconds = float(value)
        if seconds > 10_000_000_000:
            seconds /= 1000
        return datetime.fromtimestamp(seconds, UTC)
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)
        except ValueError:
            return None
    return None


def _trajectory_normalizer(adapter: str, label: str) -> Normalize:
    def normalize(native: bytes) -> object:
        from trajectory import normalize_transcript

        result = normalize_transcript(source=adapter, transcript=native.decode("utf-8"))
        records = result["records"]
        if records and records[0].get("role") == "meta":
            records[0]["source"] = label
        return records, result["diagnostics"]

    return normalize


def _expand_roots(spec_root: str) -> list[Path]:
    root = spec_root[2:] if spec_root.startswith("~/") else spec_root
    if any(ch in root for ch in "*?["):
        return [path for path in Path.home().glob(root) if path.exists()]
    path = Path.home() / root if not Path(root).is_absolute() else Path(root)
    return [path] if path.exists() else []


def file_candidates(spec: FileRoot, since: datetime | None) -> Iterator[Candidate]:
    for root in _expand_roots(spec.root):
        paths = [root] if root.is_file() else sorted(root.rglob(spec.pattern))
        for path in paths:
            if not path.is_file():
                continue
            modified = datetime.fromtimestamp(path.stat().st_mtime, UTC)
            if since and modified < since:
                continue
            yield Candidate(
                source=spec.label,
                native_id=path.stem,
                native_format=path.suffix.removeprefix(".") or "jsonl",
                native_locator=home_relative(path),
                native_modified_at=modified,
                native_size=path.stat().st_size,
                read=lambda source_path=path: stable_read(source_path),
                normalize=_trajectory_normalizer(spec.adapter, spec.label),
                updated_at=modified,
            )


def _row_dict(cursor: sqlite3.Cursor, row: tuple[object, ...]) -> dict[str, object]:
    return {description[0]: value for description, value in zip(cursor.description, row, strict=True)}


def _text(value: object) -> str | None:
    return value if isinstance(value, str) else None


def _iso(value: object, fallback: datetime) -> str:
    return (_parse_time(value) or fallback).isoformat().replace("+00:00", "Z")


def hermes_candidates(path: Path, since: datetime | None = None) -> Iterator[Candidate]:
    if not path.exists():
        return
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    connection.execute("BEGIN")
    try:
        session_cursor = connection.execute("SELECT * FROM sessions ORDER BY id")
        sessions = [_row_dict(session_cursor, row) for row in session_cursor.fetchall()]
        for session in sessions:
            modified = _parse_time(session.get("ended_at") or session.get("started_at")) or datetime.fromtimestamp(0, UTC)
            if since and modified < since:
                continue
            message_cursor = connection.execute(
                "SELECT * FROM messages WHERE session_id = ? AND active = 1 ORDER BY timestamp, id",
                (session["id"],),
            )
            messages = [_row_dict(message_cursor, row) for row in message_cursor.fetchall()]
            native = canonical_json_bytes({"session": session, "messages": messages})
            yield Candidate(
                source="hermes",
                native_id=str(session["id"]),
                native_format="hermes-export-v1",
                native_locator=home_relative(path),
                native_modified_at=modified,
                native_size=len(native),
                read=lambda value=native: value,
                normalize=_normalize_hermes,
                started_at=_parse_time(session.get("started_at")),
                updated_at=modified,
                title=_text(session.get("title")),
                cwd=_text(session.get("cwd")),
                model=_text(session.get("model")),
            )
    finally:
        connection.rollback()
        connection.close()


def _normalize_hermes(native: bytes) -> tuple[list[dict[str, object]], list[object]]:
    export = json.loads(native)
    session = export["session"]
    fallback = _parse_time(session.get("started_at")) or datetime.fromtimestamp(0, UTC)
    records: list[dict[str, object]] = [
        {
            "role": "meta",
            "source": "hermes",
            "cwd": session.get("cwd"),
            "model": session.get("model"),
        }
    ]
    for message in export["messages"]:
        timestamp = _iso(message.get("timestamp"), fallback)
        role = message.get("role")
        content = message.get("content")
        if role in {"user", "assistant", "system"} and content:
            records.append({"role": "user" if role == "system" else role, "content": str(content), "timestamp": timestamp})
        if message.get("reasoning") or message.get("reasoning_content"):
            records.append(
                {
                    "role": "reasoning",
                    "content": str(message.get("reasoning") or message.get("reasoning_content") or ""),
                    "timestamp": timestamp,
                }
            )
        tool_calls = message.get("tool_calls")
        if tool_calls:
            parsed = json.loads(tool_calls) if isinstance(tool_calls, str) else tool_calls
            if isinstance(parsed, list) and parsed:
                calls = []
                for call in parsed:
                    args = call.get("function", {}).get("arguments", call.get("arguments", {}))
                    if not isinstance(args, str):
                        args = json.dumps(args, separators=(",", ":"), sort_keys=True)
                    calls.append(
                        {
                            "id": call.get("id") or call.get("tool_call_id") or "",
                            "name": call.get("function", {}).get("name", call.get("name", "unknown")),
                            "args": args,
                        }
                    )
                records.append({"role": "assistant", "content": None, "tool_calls": calls, "timestamp": timestamp})
        if role == "tool":
            records.append(
                {
                    "role": "tool",
                    "tool_call_id": str(message.get("tool_call_id") or ""),
                    "content": str(content or ""),
                    "timestamp": timestamp,
                }
            )
    return records, []


def deepagents_candidates(path: Path, since: datetime | None = None) -> Iterator[Candidate]:
    if not path.exists():
        return
    from trajectory import list_trajectories, normalize_checkpoint

    cursor = None
    while True:
        result = list_trajectories(source="deepagents", root=path, cursor=cursor, limit=200)
        for item in result["items"]:
            modified = _parse_time(item.get("updatedAt")) or datetime.fromtimestamp(path.stat().st_mtime, UTC)
            if since and modified < since:
                continue
            thread_id = item["id"]

            def read(thread=thread_id, store=path) -> bytes:
                normalized = normalize_checkpoint(thread_id=thread, path=store)
                return canonical_json_bytes({"thread_id": thread, "records": normalized["records"], "diagnostics": normalized["diagnostics"]})

            def normalize(native: bytes) -> object:
                payload = json.loads(native)
                return payload["records"], payload["diagnostics"]

            # size is deterministic export length after first read; cheap skip uses mtime/size of store per thread export length after hashing
            native = read()
            yield Candidate(
                source="deepagents",
                native_id=thread_id,
                native_format="deepagents-export-v1",
                native_locator=home_relative(path),
                native_modified_at=modified,
                native_size=len(native),
                read=lambda value=native: value,
                normalize=normalize,
                updated_at=modified,
                title=item.get("title"),
            )
        cursor = result.get("nextCursor")
        if not cursor:
            break


def opencode_candidates(path: Path, since: datetime | None = None) -> Iterator[Candidate]:
    if not path.exists():
        return
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    connection.execute("BEGIN")
    try:
        session_cursor = connection.execute("SELECT * FROM session ORDER BY id")
        sessions = [_row_dict(session_cursor, row) for row in session_cursor.fetchall()]
        for session in sessions:
            modified = _parse_time(session.get("time_updated")) or datetime.fromtimestamp(0, UTC)
            if since and modified < since:
                continue
            message_cursor = connection.execute(
                "SELECT * FROM message WHERE session_id = ? ORDER BY time_created, id",
                (session["id"],),
            )
            messages = []
            for message in [_row_dict(message_cursor, row) for row in message_cursor.fetchall()]:
                part_cursor = connection.execute(
                    "SELECT * FROM part WHERE message_id = ? ORDER BY time_created, id",
                    (message["id"],),
                )
                parts = [_row_dict(part_cursor, row) for row in part_cursor.fetchall()]
                messages.append({"row": message, "parts": parts})
            native = canonical_json_bytes({"session": session, "messages": messages})
            yield Candidate(
                source="opencode",
                native_id=str(session["id"]),
                native_format="opencode-export-v1",
                native_locator=home_relative(path),
                native_modified_at=modified,
                native_size=len(native),
                read=lambda value=native: value,
                normalize=_normalize_opencode,
                started_at=_parse_time(session.get("time_created")),
                updated_at=modified,
                title=_text(session.get("title")),
                cwd=_text(session.get("directory")),
                model=_text(session.get("model")),
            )
    finally:
        connection.rollback()
        connection.close()


def _normalize_opencode(native: bytes) -> tuple[list[dict[str, object]], list[object]]:
    export = json.loads(native)
    session = export["session"]
    fallback = _parse_time(session.get("time_created")) or datetime.fromtimestamp(0, UTC)
    records: list[dict[str, object]] = [
        {
            "role": "meta",
            "source": "opencode",
            "cwd": session.get("directory"),
            "model": session.get("model"),
        }
    ]
    for message in export["messages"]:
        row = message["row"]
        data = json.loads(row.get("data") or "{}") if isinstance(row.get("data"), str) else (row.get("data") or {})
        role = data.get("role")
        timestamp = _iso(row.get("time_created"), fallback)
        for part in message["parts"]:
            detail = json.loads(part.get("data") or "{}") if isinstance(part.get("data"), str) else (part.get("data") or {})
            kind = detail.get("type")
            if kind == "text" and role in {"user", "assistant"}:
                records.append({"role": role, "content": detail.get("text", ""), "timestamp": timestamp})
            elif kind == "reasoning":
                records.append({"role": "reasoning", "content": detail.get("text", ""), "timestamp": timestamp})
            elif kind == "tool":
                state = detail.get("state") or {}
                call_id = detail.get("callID") or part["id"]
                records.append(
                    {
                        "role": "assistant",
                        "content": None,
                        "tool_calls": [
                            {
                                "id": call_id,
                                "name": detail.get("tool", "unknown"),
                                "args": json.dumps(state.get("input", {}), separators=(",", ":"), sort_keys=True),
                            }
                        ],
                        "timestamp": timestamp,
                    }
                )
                if state.get("status") in {"completed", "error"}:
                    records.append(
                        {
                            "role": "tool",
                            "tool_call_id": call_id,
                            "content": str(state.get("output") or state.get("error") or ""),
                            "timestamp": timestamp,
                        }
                    )
    return records, []


def amp_candidates(since: datetime | None = None, page_size: int = 100) -> Iterator[Candidate]:
    if shutil.which("amp") is None and not os.environ.get("AGENT_TRACES_TEST_AMP"):
        return
    offset = 0
    threads: list[dict[str, object]] = []
    while True:
        completed = subprocess.run(
            [
                "amp",
                "threads",
                "list",
                "--include-archived",
                "--limit",
                str(page_size),
                "--offset",
                str(offset),
                "--json",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        page = json.loads(completed.stdout)
        threads.extend(page)
        if len(page) < page_size:
            break
        offset += page_size
    for thread in threads:
        modified = _parse_time(thread.get("updated")) or datetime.fromtimestamp(0, UTC)
        if since and modified < since:
            continue
        exported = subprocess.run(
            ["amp", "threads", "export", str(thread["id"])],
            check=True,
            capture_output=True,
            text=True,
        )
        native = canonical_json_bytes(json.loads(exported.stdout))
        yield Candidate(
            source="amp",
            native_id=str(thread["id"]),
            native_format="amp-export-v1",
            native_locator=f"amp://threads/{thread['id']}",
            native_modified_at=modified,
            native_size=len(native),
            read=lambda value=native: value,
            normalize=_normalize_amp,
            updated_at=modified,
            title=_text(thread.get("title")),
        )


def _normalize_amp(native: bytes) -> tuple[list[dict[str, object]], list[object]]:
    export = json.loads(native)
    created = _parse_time(export.get("created")) or datetime.fromtimestamp(0, UTC)
    records: list[dict[str, object]] = [{"role": "meta", "source": "amp", "model": export.get("agentMode")}]
    for message in export.get("messages", []):
        role = message.get("role")
        timestamp = _iso((message.get("meta") or {}).get("sentAt"), created)
        for content in message.get("content", []):
            kind = content.get("type")
            if kind == "text" and role in {"user", "assistant"}:
                records.append({"role": role, "content": content.get("text", ""), "timestamp": timestamp})
            elif kind == "thinking":
                records.append({"role": "reasoning", "content": content.get("thinking", ""), "timestamp": timestamp})
            elif kind == "tool_use":
                records.append(
                    {
                        "role": "assistant",
                        "content": None,
                        "tool_calls": [
                            {
                                "id": content.get("id", ""),
                                "name": content.get("name", "unknown"),
                                "args": json.dumps(content.get("input", {}), separators=(",", ":"), sort_keys=True),
                            }
                        ],
                        "timestamp": timestamp,
                    }
                )
            elif kind == "tool_result":
                run = content.get("run") or {}
                records.append(
                    {
                        "role": "tool",
                        "tool_call_id": content.get("toolUseID", ""),
                        "content": str(run.get("result") or run.get("progress") or ""),
                        "timestamp": timestamp,
                    }
                )
    return records, []


def discover_candidates(since: datetime | None = None) -> Iterable[Candidate]:
    for spec in FILE_ROOTS:
        yield from file_candidates(spec, since)
    yield from hermes_candidates(Path("~/.hermes/state.db").expanduser(), since)
    yield from deepagents_candidates(Path("~/.deepagents/sessions.db").expanduser(), since)
    yield from opencode_candidates(Path("~/.local/share/opencode/opencode.db").expanduser(), since)
    yield from amp_candidates(since)
