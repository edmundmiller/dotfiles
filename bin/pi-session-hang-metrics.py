#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
"""Compute hung-command workflow KPIs from Pi session JSONL logs.

Scans structured tool-call/tool-result events, counts interactive command usage
and editor/pager failure signatures, and reports totals plus weekly trends.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

DEFAULT_SESSIONS_DIR = Path.home() / ".pi/agent/sessions/--Users-emiller-.config-dotfiles--"

REBASE_PATTERN = re.compile(r"git\s+rebase\s+(-i|--interactive)\b", re.IGNORECASE)
FAILURE_PATTERN = re.compile(
    r"terminal is dumb|EDITOR unset|cannot run .*editor|problem with the editor|waiting for your editor",
    re.IGNORECASE,
)


@dataclass(slots=True)
class SessionMetrics:
    session: str
    date: str | None
    rebase_hits: int
    failure_hits: int


@dataclass(slots=True)
class SummaryMetrics:
    sessions_scanned: int
    sessions_with_rebase: int
    sessions_with_failures: int
    rebase_hits_total: int
    failure_hits_total: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sessions-dir",
        type=Path,
        default=DEFAULT_SESSIONS_DIR,
        help=f"Session directory (default: {DEFAULT_SESSIONS_DIR})",
    )
    parser.add_argument(
        "--since",
        type=str,
        default=None,
        help="Only include sessions on/after YYYY-MM-DD",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of text")
    return parser.parse_args()


def parse_session_date(path: Path) -> date | None:
    stem = path.stem
    if "T" not in stem:
        return None
    prefix = stem.split("T", 1)[0]
    try:
        return date.fromisoformat(prefix)
    except ValueError:
        return None


def parse_since(value: str | None) -> date | None:
    if value is None:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise SystemExit(f"Invalid --since date: {value} (expected YYYY-MM-DD)") from exc


def safe_get_text(content: list[dict[str, Any]] | Any) -> str:
    if not isinstance(content, list):
        return ""
    parts: list[str] = []
    for item in content:
        if isinstance(item, dict) and item.get("type") == "text" and isinstance(item.get("text"), str):
            parts.append(item["text"])
    return "\n".join(parts)


def count_signals_in_record(record: dict[str, Any]) -> tuple[int, int]:
    if record.get("type") != "message":
        return 0, 0

    message = record.get("message")
    if not isinstance(message, dict):
        return 0, 0

    role = message.get("role")
    rebase_hits = 0
    failure_hits = 0

    if role == "assistant":
        content = message.get("content")
        if isinstance(content, list):
            for item in content:
                if not isinstance(item, dict):
                    continue
                if item.get("type") != "toolCall":
                    continue
                if item.get("name") != "bash":
                    continue
                args = item.get("arguments")
                if not isinstance(args, dict):
                    continue
                command = args.get("command")
                if isinstance(command, str):
                    rebase_hits += len(REBASE_PATTERN.findall(command))

    if role == "toolResult" and message.get("toolName") == "bash":
        content_text = safe_get_text(message.get("content"))
        failure_hits += len(FAILURE_PATTERN.findall(content_text))

        details = message.get("details")
        if isinstance(details, dict):
            details_text = "\n".join(str(v) for v in details.values())
            failure_hits += len(FAILURE_PATTERN.findall(details_text))

    return rebase_hits, failure_hits


def scan_session_file(path: Path) -> tuple[int, int]:
    rebase_hits = 0
    failure_hits = 0

    try:
        with path.open("r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(record, dict):
                    continue
                r_hits, f_hits = count_signals_in_record(record)
                rebase_hits += r_hits
                failure_hits += f_hits
    except OSError:
        return 0, 0

    return rebase_hits, failure_hits


def scan_sessions(sessions_dir: Path, since: date | None) -> list[SessionMetrics]:
    metrics: list[SessionMetrics] = []
    for file in sorted(sessions_dir.rglob("*.jsonl")):
        session_date = parse_session_date(file)
        if since and session_date and session_date < since:
            continue

        rebase_hits, failure_hits = scan_session_file(file)
        metrics.append(
            SessionMetrics(
                session=str(file),
                date=session_date.isoformat() if session_date else None,
                rebase_hits=rebase_hits,
                failure_hits=failure_hits,
            )
        )
    return metrics


def summarize(metrics: list[SessionMetrics]) -> SummaryMetrics:
    return SummaryMetrics(
        sessions_scanned=len(metrics),
        sessions_with_rebase=sum(1 for m in metrics if m.rebase_hits > 0),
        sessions_with_failures=sum(1 for m in metrics if m.failure_hits > 0),
        rebase_hits_total=sum(m.rebase_hits for m in metrics),
        failure_hits_total=sum(m.failure_hits for m in metrics),
    )


def weekly_buckets(metrics: list[SessionMetrics]) -> list[dict[str, int | str]]:
    weekly: dict[str, Counter[str]] = defaultdict(Counter)

    for m in metrics:
        if not m.date:
            continue
        d = date.fromisoformat(m.date)
        year, week_num, _ = d.isocalendar()
        key = f"{year}-W{week_num:02d}"
        weekly[key]["sessions"] += 1
        if m.rebase_hits > 0:
            weekly[key]["sessions_with_rebase"] += 1
        if m.failure_hits > 0:
            weekly[key]["sessions_with_failures"] += 1
        weekly[key]["rebase_hits_total"] += m.rebase_hits
        weekly[key]["failure_hits_total"] += m.failure_hits

    return [
        {
            "week": week,
            "sessions": stats["sessions"],
            "sessions_with_rebase": stats["sessions_with_rebase"],
            "sessions_with_failures": stats["sessions_with_failures"],
            "rebase_hits_total": stats["rebase_hits_total"],
            "failure_hits_total": stats["failure_hits_total"],
        }
        for week, stats in sorted(weekly.items())
    ]


def top_sessions(metrics: list[SessionMetrics], *, limit: int = 10) -> list[dict[str, int | str | None]]:
    ranked = sorted(
        metrics,
        key=lambda m: (m.failure_hits, m.rebase_hits),
        reverse=True,
    )
    return [asdict(m) for m in ranked if (m.failure_hits > 0 or m.rebase_hits > 0)][:limit]


def render_text(
    summary: SummaryMetrics,
    weekly: list[dict[str, int | str]],
    top: list[dict[str, int | str | None]],
) -> str:
    lines = [
        "pi hung-command KPI report",
        f"sessions_scanned: {summary.sessions_scanned}",
        f"sessions_with_rebase: {summary.sessions_with_rebase}",
        f"sessions_with_failures: {summary.sessions_with_failures}",
        f"rebase_hits_total: {summary.rebase_hits_total}",
        f"failure_hits_total: {summary.failure_hits_total}",
        "",
        "weekly:",
    ]

    if not weekly:
        lines.append("  (no dated sessions found)")
    else:
        for row in weekly:
            lines.append(
                "  "
                + f"{row['week']}: sessions={row['sessions']} rebase_sessions={row['sessions_with_rebase']} "
                + f"failure_sessions={row['sessions_with_failures']} rebase_hits={row['rebase_hits_total']} "
                + f"failure_hits={row['failure_hits_total']}"
            )

    lines.append("")
    lines.append("top_sessions:")
    if not top:
        lines.append("  (none)")
    else:
        for row in top:
            lines.append(
                "  "
                + f"{row['date'] or 'unknown'} rebase_hits={row['rebase_hits']} "
                + f"failure_hits={row['failure_hits']} {row['session']}"
            )

    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    since = parse_since(args.since)

    if not args.sessions_dir.exists():
        raise SystemExit(f"Sessions dir does not exist: {args.sessions_dir}")

    metrics = scan_sessions(args.sessions_dir, since)
    summary = summarize(metrics)
    weekly = weekly_buckets(metrics)
    top = top_sessions(metrics)

    payload = {
        "generated_at": datetime.now(UTC).isoformat(),
        "sessions_dir": str(args.sessions_dir),
        "since": since.isoformat() if since else None,
        "summary": asdict(summary),
        "weekly": weekly,
        "top_sessions": top,
    }

    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(render_text(summary, weekly, top))


if __name__ == "__main__":
    main()
