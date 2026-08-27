#!/usr/bin/env python3
"""Reconcile host-managed MCP entries in Codex's writable configuration."""

import argparse
import os
import pathlib
import re
import stat
import tempfile
import tomllib


def enabled_flag(value: str) -> bool:
    if value not in {"0", "1"}:
        raise argparse.ArgumentTypeError("expected 0 or 1")
    return value == "1"


def remove_server(content: str, server_name: str) -> str:
    server_prefix = r"[ \t]*mcp_servers[ \t]*\.[ \t]*" + re.escape(server_name)
    pattern = re.compile(
        r"(?ms)^[ \t]*\["
        + server_prefix
        + r"(?:[ \t]*\.[ \t]*[^\]\r\n]+)?[ \t]*\]"
        + r"[ \t]*(?:#[^\r\n]*)?(?:\r?\n|\Z)"
        + r".*?(?=^[ \t]*\[(?!"
        + server_prefix
        + r"(?:[ \t]*\.|[ \t]*\]))|\Z)"
    )
    return pattern.sub("", content)


def require_managed_servers_removed(content: str) -> None:
    parsed = tomllib.loads(content)
    servers = parsed.get("mcp_servers", {})
    if not isinstance(servers, dict):
        raise ValueError("mcp_servers must be a table")
    remaining = sorted({"homeassistant", "seqera"}.intersection(servers))
    if remaining:
        raise ValueError(
            "unsupported managed MCP table syntax: " + ", ".join(remaining)
        )


def remove_legacy_entries(content: str) -> str:
    content = re.sub(
        r"(?ms)^[ \t]*\[\[hooks\.(?:PostToolUse|PreToolUse|Stop)\]\]\n\n"
        r"[ \t]*\[\[hooks\.(?:PostToolUse|PreToolUse|Stop)\.hooks\]\]\n"
        r'command = "/Users/emiller/\.git-ai/bin/git-ai checkpoint codex --hook-input stdin"\n'
        r'type = "command"\n\n?',
        "",
        content,
    )
    content = re.sub(
        r'(?ms)^[ \t]*\[hooks\.state\."/Users/emiller/\.codex/config\.toml:'
        r'(?:post_tool_use|pre_tool_use|stop):0:0"\]\n.*?(?=^[ \t]*\[|\Z)',
        "",
        content,
    )
    return remove_server(remove_server(content, "codegraph"), "node_repl")


def enable_rmcp_client(content: str) -> str:
    features_pattern = re.compile(
        r"(?ms)^[ \t]*\[[ \t]*features[ \t]*\][ \t]*"
        r"(?:#[^\r\n]*)?(?:\r?\n|\Z).*?(?=^[ \t]*\[|\Z)"
    )
    features_match = features_pattern.search(content)
    if features_match is None:
        if "features" in tomllib.loads(content):
            raise ValueError("unsupported features table syntax")
        return content.rstrip() + "\n\n[features]\nrmcp_client = true\n"

    features = features_match.group()
    if re.search(r"(?m)^rmcp_client\s*=", features):
        features = re.sub(r"(?m)^rmcp_client\s*=.*$", "rmcp_client = true", features)
    else:
        features = features.rstrip() + "\nrmcp_client = true\n"
    return (
        content[: features_match.start()] + features + content[features_match.end() :]
    )


def append_table(content: str, table: str) -> str:
    return content.rstrip() + "\n\n" + table.rstrip() + "\n"


def replace_atomically(path: pathlib.Path, content: str) -> None:
    temporary_path: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            delete=False,
        ) as temporary:
            temporary_path = pathlib.Path(temporary.name)
            temporary.write(content)
            temporary.flush()
            os.fsync(temporary.fileno())
        if path.exists():
            os.chmod(temporary_path, stat.S_IMODE(path.stat().st_mode))
        os.replace(temporary_path, path)
        temporary_path = None
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def reconcile(
    content: str,
    *,
    seqera_mcp_enabled: bool,
    home_assistant_mcp_enabled: bool,
    legacy_cleanup: bool = False,
) -> str:
    next_content = remove_legacy_entries(content) if legacy_cleanup else content
    next_content = remove_server(next_content, "seqera")
    next_content = remove_server(next_content, "homeassistant")
    require_managed_servers_removed(next_content)

    if seqera_mcp_enabled or home_assistant_mcp_enabled:
        next_content = enable_rmcp_client(next_content)

    if seqera_mcp_enabled:
        next_content = append_table(
            next_content,
            '[mcp_servers.seqera]\nurl = "https://mcp.seqera.io/mcp"',
        )

    if home_assistant_mcp_enabled:
        parsed = tomllib.loads(next_content)
        callback_port = parsed.get("mcp_oauth_callback_port")
        if callback_port is None:
            callback_port = 12345
            next_content = (
                f"mcp_oauth_callback_port = {callback_port}\n\n" + next_content.lstrip()
            )
        elif type(callback_port) is not int or not 1 <= callback_port <= 65535:
            raise ValueError(
                "mcp_oauth_callback_port must be an integer from 1 to 65535"
            )
        next_content = append_table(
            next_content,
            "[mcp_servers.homeassistant]\n"
            'url = "https://homeassistant.cinnamon-rooster.ts.net/api/mcp"\n'
            'auth = "oauth"\n'
            f'oauth = {{ client_id = "http://127.0.0.1:{callback_port}" }}',
        )

    next_content = next_content.rstrip() + "\n"
    tomllib.loads(next_content)
    return next_content


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--legacy-cleanup", action="store_true")
    parser.add_argument("path", type=pathlib.Path)
    parser.add_argument("seqera_mcp_enabled", type=enabled_flag)
    parser.add_argument("home_assistant_mcp_enabled", type=enabled_flag)
    args = parser.parse_args()

    if args.path.is_symlink():
        raise RuntimeError(f"refusing to replace symlink: {args.path}")
    if args.path.exists() and not args.path.is_file():
        raise RuntimeError(f"refusing to replace non-file: {args.path}")
    content = args.path.read_text(encoding="utf-8") if args.path.exists() else ""
    next_content = reconcile(
        content,
        seqera_mcp_enabled=args.seqera_mcp_enabled,
        home_assistant_mcp_enabled=args.home_assistant_mcp_enabled,
        legacy_cleanup=args.legacy_cleanup,
    )
    changed = next_content != content
    if not args.dry_run and changed:
        replace_atomically(args.path, next_content)
    prefix = "would_change" if args.dry_run else "changed"
    print(f"{prefix}={str(changed).lower()}")


if __name__ == "__main__":
    main()
