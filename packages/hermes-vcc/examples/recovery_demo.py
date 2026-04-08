#!/usr/bin/env python3
"""Recovery tool demo.

Demonstrates:
  1. Archiving a conversation with multiple compression cycles.
  2. Using handle_vcc_recover() with each action: list, overview, search, read.
  3. Showing how an agent would use the tool after compression.
"""

import json
import tempfile
from pathlib import Path

from hermes_vcc.archive import archive_before_compression
from hermes_vcc.recovery import handle_vcc_recover


def main() -> None:
    session_id = "recovery-demo"

    with tempfile.TemporaryDirectory(prefix="hermes_vcc_recovery_demo_") as tmpdir:
        archive_dir = Path(tmpdir)

        # -- Build a conversation with a database migration error --
        messages = [
            {"role": "system", "content": "You are a DevOps assistant."},
            {"role": "user", "content": "Deploy the latest migration to staging."},
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": "call_migrate",
                        "type": "function",
                        "function": {
                            "name": "bash",
                            "arguments": json.dumps({
                                "command": "python manage.py migrate --database=staging"
                            }),
                        },
                    }
                ],
            },
            {
                "role": "tool",
                "content": (
                    "Running migrations on staging...\n"
                    "Applying auth.0012_alter_user_first_name... OK\n"
                    "Applying core.0045_create_users_v2...\n"
                    'Error: relation "users_v2" already exists\n'
                    "django.db.utils.ProgrammingError: relation already exists\n"
                    "Migration failed with exit code 1"
                ),
                "tool_call_id": "call_migrate",
            },
            {
                "role": "assistant",
                "content": (
                    "The migration failed because the `users_v2` table already exists. "
                    "This is likely from a previous partial migration. "
                    "I'll fix it by adding `IF NOT EXISTS` to the migration."
                ),
            },
            {"role": "user", "content": "Yes, please fix it."},
            {
                "role": "assistant",
                "content": "<think>I need to edit the migration file to add IF NOT EXISTS.</think>",
                "tool_calls": [
                    {
                        "id": "call_fix",
                        "type": "function",
                        "function": {
                            "name": "write_file",
                            "arguments": json.dumps({
                                "path": "core/migrations/0045_create_users_v2.py",
                                "content": "# Fixed migration with IF NOT EXISTS\n...",
                            }),
                        },
                    }
                ],
            },
            {
                "role": "tool",
                "content": "File written: core/migrations/0045_create_users_v2.py",
                "tool_call_id": "call_fix",
            },
            {
                "role": "assistant",
                "content": None,
                "tool_calls": [
                    {
                        "id": "call_retry",
                        "type": "function",
                        "function": {
                            "name": "bash",
                            "arguments": json.dumps({
                                "command": "python manage.py migrate --database=staging"
                            }),
                        },
                    }
                ],
            },
            {
                "role": "tool",
                "content": (
                    "Running migrations on staging...\n"
                    "Applying core.0045_create_users_v2... OK\n"
                    "Applying core.0046_add_email_index... OK\n"
                    "All migrations applied successfully."
                ),
                "tool_call_id": "call_retry",
            },
            {
                "role": "assistant",
                "content": "Migration completed successfully on staging.",
            },
        ]

        # -- Archive the conversation --
        print("=== Archiving conversation ===")
        archive_before_compression(
            messages=messages,
            session_id=session_id,
            archive_dir=archive_dir,
            compression_cycle=1,
        )
        print(f"Archived {len(messages)} messages as cycle 1.\n")

        # -- Action: list --
        print("=" * 60)
        print("ACTION: list")
        print("=" * 60)
        result = handle_vcc_recover(
            action="list",
            archive_dir=archive_dir,
            session_id=session_id,
        )
        print(result)
        print()

        # -- Action: overview --
        print("=" * 60)
        print("ACTION: overview (latest cycle)")
        print("=" * 60)
        result = handle_vcc_recover(
            action="overview",
            archive_dir=archive_dir,
            session_id=session_id,
        )
        print(result)
        print()

        # -- Action: search --
        print("=" * 60)
        print('ACTION: search (query="migration.*error")')
        print("=" * 60)
        result = handle_vcc_recover(
            action="search",
            query="migration.*error",
            archive_dir=archive_dir,
            session_id=session_id,
        )
        print(result)
        print()

        # -- Action: search (regex) --
        print("=" * 60)
        print('ACTION: search (query="users_v2")')
        print("=" * 60)
        result = handle_vcc_recover(
            action="search",
            query="users_v2",
            archive_dir=archive_dir,
            session_id=session_id,
        )
        print(result)
        print()

        # -- Action: read --
        print("=" * 60)
        print('ACTION: read (lines 1-10)')
        print("=" * 60)
        result = handle_vcc_recover(
            action="read",
            query="1-10",
            archive_dir=archive_dir,
            session_id=session_id,
        )
        print(result)
        print()

        # -- Edge case: invalid action --
        print("=" * 60)
        print("ACTION: invalid")
        print("=" * 60)
        result = handle_vcc_recover(
            action="invalid",
            archive_dir=archive_dir,
            session_id=session_id,
        )
        print(result)
        print()

        # -- Edge case: search with no query --
        print("=" * 60)
        print("ACTION: search (no query)")
        print("=" * 60)
        result = handle_vcc_recover(
            action="search",
            archive_dir=archive_dir,
            session_id=session_id,
        )
        print(result)


if __name__ == "__main__":
    main()
