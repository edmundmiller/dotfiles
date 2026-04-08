#!/usr/bin/env python3
"""Basic standalone usage of hermes-vcc.

Demonstrates:
  1. Creating sample OpenAI-format messages.
  2. Converting them to VCC JSONL records via the adapter.
  3. Writing the JSONL to disk.
  4. Compiling with VCC (if the vendored module is available).
  5. Printing the output paths and content.
"""

import json
import tempfile
from pathlib import Path

from hermes_vcc.adapter import convert_conversation, records_to_jsonl


def main() -> None:
    # -- 1. Sample conversation in OpenAI chat format --
    messages = [
        {"role": "system", "content": "You are a helpful coding assistant."},
        {"role": "user", "content": "Read the contents of main.py"},
        {
            "role": "assistant",
            "content": "Let me read that file for you.",
            "tool_calls": [
                {
                    "id": "call_001",
                    "type": "function",
                    "function": {
                        "name": "read_file",
                        "arguments": json.dumps({"path": "main.py"}),
                    },
                }
            ],
        },
        {
            "role": "tool",
            "content": 'def main():\n    print("hello world")\n\nif __name__ == "__main__":\n    main()',
            "tool_call_id": "call_001",
        },
        {
            "role": "assistant",
            "content": (
                "The file `main.py` contains a simple hello-world script. "
                "It defines a `main()` function that prints 'hello world' "
                "and calls it when run as a script."
            ),
        },
        {"role": "user", "content": "Add a command-line argument parser to it."},
        {
            "role": "assistant",
            "content": "<think>I should use argparse for this.</think>I'll add argparse to the script.",
            "tool_calls": [
                {
                    "id": "call_002",
                    "type": "function",
                    "function": {
                        "name": "write_file",
                        "arguments": json.dumps({
                            "path": "main.py",
                            "content": (
                                "import argparse\n\n"
                                "def main():\n"
                                "    parser = argparse.ArgumentParser()\n"
                                "    parser.add_argument('--name', default='world')\n"
                                "    args = parser.parse_args()\n"
                                "    print(f'hello {args.name}')\n\n"
                                "if __name__ == '__main__':\n"
                                "    main()\n"
                            ),
                        }),
                    },
                }
            ],
        },
        {
            "role": "tool",
            "content": "File written successfully: main.py (198 bytes)",
            "tool_call_id": "call_002",
        },
        {
            "role": "assistant",
            "content": "Done. The script now accepts a `--name` argument.",
        },
    ]

    # -- 2. Convert to VCC JSONL records --
    records = convert_conversation(messages)

    print(f"Converted {len(messages)} messages to {len(records)} VCC records.\n")

    # -- 3. Serialize and write to disk --
    jsonl_text = records_to_jsonl(records)

    with tempfile.TemporaryDirectory(prefix="hermes_vcc_demo_") as tmpdir:
        work_dir = Path(tmpdir)
        jsonl_path = work_dir / "demo.jsonl"
        jsonl_path.write_text(jsonl_text, encoding="utf-8")

        print(f"JSONL written to: {jsonl_path}")
        print(f"JSONL size: {len(jsonl_text)} bytes\n")

        # Print first few records for inspection.
        print("=== First 3 JSONL records ===")
        for line in jsonl_text.strip().split("\n")[:3]:
            parsed = json.loads(line)
            print(json.dumps(parsed, indent=2))
            print()

        # -- 4. Compile with VCC (optional) --
        try:
            from hermes_vcc.utils import import_vcc

            vcc = import_vcc()
            vcc.compile_pass(
                str(jsonl_path),
                str(work_dir),
                truncate=128,
                truncate_user=256,
                quiet=True,
            )

            # -- 5. Show output paths and content --
            txt_path = work_dir / "demo.txt"
            min_path = work_dir / "demo.min.txt"

            if txt_path.exists():
                content = txt_path.read_text(encoding="utf-8")
                print(f"=== Full transcript ({txt_path.name}, {len(content)} chars) ===")
                print(content[:2000])
                if len(content) > 2000:
                    print(f"... (truncated, {len(content)} total chars)")
                print()

            if min_path.exists():
                content = min_path.read_text(encoding="utf-8")
                print(f"=== Brief transcript ({min_path.name}, {len(content)} chars) ===")
                print(content[:2000])
                if len(content) > 2000:
                    print(f"... (truncated, {len(content)} total chars)")
                print()

        except (FileNotFoundError, ImportError) as exc:
            print(f"VCC compilation skipped (VCC not available): {exc}")
            print("The JSONL file was still written successfully.")
            print("Install VCC.py in vendor/ to enable compilation.")


if __name__ == "__main__":
    main()
