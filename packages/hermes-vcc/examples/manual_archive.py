#!/usr/bin/env python3
"""Manual archive creation demo.

Demonstrates:
  1. Creating a sample conversation.
  2. Archiving it with archive_before_compression().
  3. Inspecting the manifest.
  4. Archiving a second cycle with additional messages.
  5. Showing the complete archive structure.
"""

import json
import tempfile
from pathlib import Path

from hermes_vcc.archive import (
    archive_before_compression,
    get_archive_manifest,
    prune_archives,
)


def main() -> None:
    session_id = "demo-session-001"

    with tempfile.TemporaryDirectory(prefix="hermes_vcc_archive_demo_") as tmpdir:
        archive_dir = Path(tmpdir)

        # -- Cycle 1: Initial conversation --
        messages_cycle_1 = [
            {"role": "system", "content": "You are a database administrator."},
            {"role": "user", "content": "Check the status of the PostgreSQL service."},
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": "call_pg_status",
                        "type": "function",
                        "function": {
                            "name": "bash",
                            "arguments": json.dumps({"command": "systemctl status postgresql"}),
                        },
                    }
                ],
            },
            {
                "role": "tool",
                "content": "postgresql.service - PostgreSQL RDBMS\n   Active: active (running)\n   Memory: 128.4M",
                "tool_call_id": "call_pg_status",
            },
            {
                "role": "assistant",
                "content": "PostgreSQL is running and using 128.4M of memory.",
            },
        ]

        print("=== Archiving Cycle 1 ===")
        session_dir = archive_before_compression(
            messages=messages_cycle_1,
            session_id=session_id,
            archive_dir=archive_dir,
            compression_cycle=1,
        )
        print(f"Session directory: {session_dir}")

        # Show manifest after cycle 1.
        manifest = get_archive_manifest(session_dir)
        print(f"\nManifest after cycle 1:")
        print(json.dumps(manifest, indent=2))

        # -- Cycle 2: Conversation continues --
        messages_cycle_2 = messages_cycle_1 + [
            {"role": "user", "content": "Run a vacuum analyze on the users table."},
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": "call_vacuum",
                        "type": "function",
                        "function": {
                            "name": "bash",
                            "arguments": json.dumps({
                                "command": "psql -c 'VACUUM ANALYZE users;'"
                            }),
                        },
                    }
                ],
            },
            {
                "role": "tool",
                "content": "VACUUM\nTime: 342.5 ms",
                "tool_call_id": "call_vacuum",
            },
            {
                "role": "assistant",
                "content": "Vacuum analyze completed on the users table in 342.5ms.",
            },
            {
                "role": "user",
                "content": "Show me the table sizes.",
            },
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": "call_sizes",
                        "type": "function",
                        "function": {
                            "name": "bash",
                            "arguments": json.dumps({
                                "command": "psql -c \"SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) FROM pg_class WHERE relkind='r' ORDER BY pg_total_relation_size(oid) DESC LIMIT 5;\""
                            }),
                        },
                    }
                ],
            },
            {
                "role": "tool",
                "content": "  relname  | pg_size_pretty\n-----------+----------------\n users     | 2457 MB\n orders    | 1823 MB\n events    | 945 MB\n sessions  | 512 MB\n logs      | 234 MB",
                "tool_call_id": "call_sizes",
            },
            {
                "role": "assistant",
                "content": "Here are the top 5 tables by size. The users table is the largest at 2.4 GB.",
            },
        ]

        print("\n=== Archiving Cycle 2 ===")
        session_dir = archive_before_compression(
            messages=messages_cycle_2,
            session_id=session_id,
            archive_dir=archive_dir,
            compression_cycle=2,
        )

        # Show updated manifest.
        manifest = get_archive_manifest(session_dir)
        print(f"\nManifest after cycle 2:")
        print(json.dumps(manifest, indent=2))

        # -- List archive files --
        print("\n=== Archive Directory Contents ===")
        for path in sorted(session_dir.iterdir()):
            size = path.stat().st_size
            print(f"  {path.name:30s}  {size:>8,} bytes")

        # -- Demonstrate pruning --
        print("\n=== Pruning (retain=1) ===")
        prune_archives(session_dir, retain=1)

        manifest = get_archive_manifest(session_dir)
        print(f"Manifest after pruning:")
        print(json.dumps(manifest, indent=2))

        print("\nRemaining files:")
        for path in sorted(session_dir.iterdir()):
            size = path.stat().st_size
            print(f"  {path.name:30s}  {size:>8,} bytes")


if __name__ == "__main__":
    main()
