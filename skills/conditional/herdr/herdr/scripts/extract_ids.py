#!/usr/bin/env python3
"""Extract workspace/tab/pane ids from Herdr JSON output.

Useful in shell pipelines with `herdr workspace create`, `herdr tab create`, or
`herdr pane split`.
"""

from __future__ import annotations

import argparse
import json
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract ids from Herdr JSON output read on stdin.")
    parser.add_argument(
        "field",
        choices=["workspace", "tab", "pane"],
        help="Which id to print",
    )
    args = parser.parse_args()

    payload = json.load(sys.stdin)
    result = payload["result"]

    if args.field == "workspace":
        print(result["workspace"]["workspace_id"])
    elif args.field == "tab":
        print(result["tab"]["tab_id"])
    else:
        # workspace create/tab create call this root_pane; pane split calls it pane.
        pane = result.get("root_pane") or result.get("pane")
        if pane is None:
            raise KeyError("result did not contain root_pane or pane")
        print(pane["pane_id"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
