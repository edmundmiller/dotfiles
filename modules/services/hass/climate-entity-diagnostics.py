#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["websockets>=15,<17"]
# ///
"""Read-only fixed-entity mapping and bounded, categorized journal evidence."""

from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys

from websockets.sync.client import connect

ENTITY = "climate.master_suite"
# Five-minute margins around the assessment's recovered intervals, merged where overlapping.
WINDOWS = tuple(
    (datetime.fromisoformat(f"2026-11-10T{start}+00:00"),
     datetime.fromisoformat(f"2026-11-10T{end}+00:00"))
    for start, end in (
        ("06:15:00", "06:38:00"), ("08:44:00", "09:09:00"),
        ("09:39:00", "10:03:00"), ("10:42:00", "10:58:00"),
        ("13:43:00", "14:07:00"), ("14:39:00", "15:02:00"),
        ("15:34:00", "15:59:00"),
    )
)
CATEGORIES = (
    ("timeout", r"timed? out|timeout"),
    ("authentication", r"unauthori[sz]ed|forbidden|authentication|invalid.auth|\b40[13]\b"),
    ("rate_limited", r"rate.limit|too many requests|\b429\b"),
    ("connection_failure", r"connection.*(?:refused|reset|closed|failed|broken)|cannot connect|unable to connect|network.*unreachable"),
    ("unavailable", r"unavailable|offline|not responding"),
)


def request(socket, request_id, command, **fields):
    socket.send(json.dumps({"id": request_id, "type": command, **fields}))
    reply = json.loads(socket.recv(timeout=10))
    if (reply.get("id") != request_id or reply.get("type") != "result"
            or not reply.get("success")):
        raise ValueError("Read failed")
    return reply["result"]


def mapping(socket):
    entity = request(socket, 1, "config/entity_registry/get", entity_id=ENTITY)
    platform = entity["platform"]
    entry_id = entity["config_entry_id"]
    if (entity["entity_id"] != ENTITY or not re.fullmatch(r"[a-z0-9_]+", platform)
            or not re.fullmatch(r"[A-Za-z0-9]+", entry_id)):
        raise ValueError("Unsupported mapping")
    entries = request(socket, 2, "config_entries/get")
    entry = next(item for item in entries if item["entry_id"] == entry_id)
    if not re.fullmatch(r"[a-z0-9_]+", entry["domain"]):
        raise ValueError("Unsupported domain")
    state = entry["state"]
    return {
        "entity_id": ENTITY,
        "platform": platform,
        "config_entry_id": entry_id,
        "integration_domain": entry["domain"],
        "integration_state": state if state in {
            "loaded", "not_loaded", "setup_error", "setup_retry", "migration_error",
            "failed_unload", "setup_in_progress", "unload_in_progress",
        } else "other",
        "entity_disabled": entity.get("disabled_by") is not None,
        "integration_disabled": entry.get("disabled_by") is not None,
    }


def journal_summary(text, entity_mapping):
    counts = Counter()
    matched_times = []
    window_records = 0
    binary_messages = 0
    domain = re.escape(entity_mapping["integration_domain"])
    platform = re.escape(entity_mapping["platform"])
    logger = re.compile(r"\[homeassistant\.components\.(?:" + domain + "|" + platform + r")(?:\.[^\]]*)?\]")
    identity = re.compile(
        r"(?<![A-Za-z0-9_.])(?:" + re.escape(ENTITY) + "|"
        + re.escape(entity_mapping["config_entry_id"]) + r")(?![A-Za-z0-9_.])"
    )
    for line in text.splitlines():
        record = json.loads(line)
        observed = datetime.fromtimestamp(int(record["__REALTIME_TIMESTAMP"]) / 1_000_000, timezone.utc)
        if not any(start <= observed <= end for start, end in WINDOWS):
            continue
        window_records += 1
        message = record.get("MESSAGE")
        if not isinstance(message, str):
            binary_messages += 1
            continue
        if not re.search(r"\b(?:ERROR|WARNING|CRITICAL)\b", message):
            continue
        if identity.search(message):
            scope = "entity_or_config_entry"
        elif logger.search(message):
            scope = "integration_wide_not_entity_specific"
        else:
            continue
        categories = [code for code, pattern in CATEGORIES if re.search(pattern, message, re.I)]
        for category in categories or ["unclassified_warning_or_error"]:
            counts[scope, category] += 1
        matched_times.append(observed.isoformat())
    return {
        "windows": [{"start": start.isoformat(), "end": end.isoformat()} for start, end in WINDOWS],
        "retained_records_in_windows": window_records,
        "nontext_messages_not_classified": binary_messages,
        "matched_records": len(matched_times),
        "first_match": min(matched_times) if matched_times else None,
        "last_match": max(matched_times) if matched_times else None,
        "category_counts": [{"scope": scope, "category": category, "count": count}
                            for (scope, category), count in sorted(counts.items())],
        "coverage": "Retained warning/error messages matching the entity/config entry or mapped component logger only. Integration-wide errors are not attributed to this thermostat. Category counts can overlap. Zero matches do not prove absence of transport errors or journal retention.",
    }


def main():
    token = Path("/run/agenix/ha-hermes-token").read_text().strip()
    with connect("ws://127.0.0.1:8123/api/websocket", open_timeout=10,
                 close_timeout=1, max_size=16 * 1024 * 1024, proxy=None) as socket:
        if json.loads(socket.recv(timeout=10)).get("type") != "auth_required":
            raise ValueError("Unexpected handshake")
        socket.send(json.dumps({"type": "auth", "access_token": token}))
        if json.loads(socket.recv(timeout=10)).get("type") != "auth_ok":
            raise ValueError("Authentication failed")
        entity_mapping = mapping(socket)
    try:
        journal = subprocess.run(
            ["journalctl", "-u", "home-assistant.service", "--since", WINDOWS[0][0].isoformat(),
             "--until", WINDOWS[-1][1].isoformat(), "-o", "json", "--no-pager"],
            capture_output=True, text=True, check=True, timeout=20,
        )
        summary = journal_summary(journal.stdout, entity_mapping)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        summary = {"status": "unknown", "error_type": type(error).__name__}
    print(json.dumps({
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "mapping": entity_mapping, "journal": summary,
        "omitted": ["titles", "unique_ids", "device_ids", "attributes", "options", "credentials", "addresses", "raw_messages", "free_form_errors"],
    }, sort_keys=True))
    return 0 if summary.get("retained_records_in_windows") else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(json.dumps({"status": "unknown", "error_type": type(error).__name__}))
        sys.exit(2)
