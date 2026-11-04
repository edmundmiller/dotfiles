#!/usr/bin/env python3
"""Warn when a Claude Code session grows past a context budget or is resumed stale.

The hook never blocks: it exits 0 on every path, prints nothing when it has
nothing to say, and stays silent on malformed input or an unreadable transcript.
See https://code.claude.com/docs/en/hooks for the input and output contracts.
"""

import datetime as dt
import hashlib
import json
import os
import pathlib
import re
import sys

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - Python 3.9+ ships zoneinfo
    ZoneInfo = None

DEFAULT_WARN_TOKENS = 250_000
DEFAULT_STEP_TOKENS = 100_000
HEAD_LINES = 200
TAIL_BYTES = 1 << 20
SESSION_TIMEZONE = "America/Chicago"
USAGE_FIELDS = ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
SAFE_SESSION_ID = re.compile(r"\A[A-Za-z0-9._-]{1,128}\Z")


def env_int(name, default):
    try:
        return int(os.environ[name])
    except (KeyError, ValueError):
        return default


def state_dir():
    override = os.environ.get("CLAUDE_SESSION_BUDGET_STATE_DIR")
    if override:
        return pathlib.Path(override)
    cache = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return pathlib.Path(cache) / "claude-session-budget"


def state_path(session_id):
    name = session_id
    if not SAFE_SESSION_ID.match(name):
        name = hashlib.sha256(name.encode("utf-8", "replace")).hexdigest()
    return state_dir() / f"{name}.json"


def read_state(path):
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return state if isinstance(state, dict) else {}


def write_state(path, state):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(state) + "\n", encoding="utf-8")
    except OSError:
        # A warning the hook cannot record is still worth printing once.
        pass


def decode_entries(lines):
    """Main-thread transcript entries, skipping subagent turns and junk lines."""
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if isinstance(entry, dict) and not entry.get("isSidechain"):
            yield entry


def head_lines(transcript_path, count=HEAD_LINES):
    if not transcript_path:
        return []
    try:
        with open(transcript_path, encoding="utf-8", errors="replace") as handle:
            return [line for _, line in zip(range(count), handle)]
    except OSError:
        return []


def tail_lines(transcript_path, limit=TAIL_BYTES):
    """The end of the transcript, so a multi-gigabyte session stays cheap to read."""
    if not transcript_path:
        return []
    try:
        with open(transcript_path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            start = max(0, handle.tell() - limit)
            handle.seek(start)
            chunk = handle.read()
    except OSError:
        return []
    lines = chunk.decode("utf-8", "replace").splitlines()
    # The first line is cut in half unless the read started at the beginning.
    return lines[1:] if start and lines else lines


def context_tokens(transcript_path):
    """Context size from the newest assistant usage, as Claude Code reports it."""
    tokens = None
    for entry in decode_entries(tail_lines(transcript_path)):
        if entry.get("type") != "assistant":
            continue
        message = entry.get("message")
        usage = message.get("usage") if isinstance(message, dict) else None
        if not isinstance(usage, dict):
            continue
        total = 0
        for field in USAGE_FIELDS:
            value = usage.get(field, 0)
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                continue
            total += int(value)
        tokens = total
    return tokens


def session_zone():
    if ZoneInfo is not None:
        try:
            return ZoneInfo(SESSION_TIMEZONE)
        except Exception:
            # No tzdata: the machine's own zone is the next best reference.
            pass
    return dt.datetime.now().astimezone().tzinfo


def first_entry_date(transcript_path, zone):
    for entry in decode_entries(head_lines(transcript_path)):
        stamp = entry.get("timestamp")
        if not isinstance(stamp, str):
            continue
        try:
            parsed = dt.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        except ValueError:
            continue
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(zone).date()
    return None


def context_warning(payload, state):
    threshold = env_int("CLAUDE_CONTEXT_WARN_TOKENS", DEFAULT_WARN_TOKENS)
    if threshold <= 0:
        return None
    step = env_int("CLAUDE_CONTEXT_WARN_STEP_TOKENS", DEFAULT_STEP_TOKENS)
    if step <= 0:
        step = DEFAULT_STEP_TOKENS

    tokens = context_tokens(payload.get("transcript_path"))
    if tokens is None or tokens < threshold:
        return None

    level = 1 + (tokens - threshold) // step
    if level <= state.get("context_level", 0):
        return None
    state["context_level"] = level

    return (
        f"Context is about {tokens:,} tokens, past the {threshold:,} warning threshold. "
        "Run /compact or finish here and start a fresh session: every further turn "
        "re-sends this whole context."
    )


def stale_resume_warning(payload, state):
    zone = session_zone()
    today = dt.datetime.now(zone).date()
    started = first_entry_date(payload.get("transcript_path"), zone)
    if started is None or started >= today:
        return None
    if state.get("resume_warned_on") == today.isoformat():
        return None
    state["resume_warned_on"] = today.isoformat()

    days = (today - started).days
    return (
        f"This session started {days} day(s) ago, on {started.isoformat()} "
        f"({SESSION_TIMEZONE}). Resuming it re-sends its whole accumulated context on "
        "every turn. Start a fresh session unless you need this exact history."
    )


def warnings_for(payload):
    event = payload.get("hook_event_name")
    if event == "SessionStart" and payload.get("source") != "resume":
        return []

    session_id = payload.get("session_id")
    path = state_path(session_id if isinstance(session_id, str) and session_id else "unknown")
    state = read_state(path)
    before = dict(state)

    messages = []
    if event == "SessionStart":
        messages.append(stale_resume_warning(payload, state))
    messages.append(context_warning(payload, state))

    if state != before:
        write_state(path, state)
    return [message for message in messages if message]


def main():
    try:
        payload = json.loads(sys.stdin.read())
        if not isinstance(payload, dict):
            return 0
        messages = warnings_for(payload)
    except Exception:
        return 0

    if not messages:
        return 0

    text = "\n".join(messages)
    output = {"systemMessage": text}
    event = payload.get("hook_event_name")
    # Stop treats additionalContext as a reason to keep the turn going, so the
    # model only hears about the budget on events that start work.
    if event in ("UserPromptSubmit", "SessionStart"):
        output["hookSpecificOutput"] = {"hookEventName": event, "additionalContext": text}
    print(json.dumps(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
