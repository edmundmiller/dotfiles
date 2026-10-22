#!/usr/bin/env -S uv run --script
# /// script
# dependencies = ["json5", "tomlkit"]
# ///
"""Render and reconcile host-owned MCP servers without owning agent state."""

import argparse
import json
import os
from pathlib import Path
import tempfile

import json5
import tomlkit


TARGETS = {
    "pi": (".pi/agent/mcp.json", ("mcpServers",)),
    "omp": (".omp/agent/mcp.json", ("mcpServers",)),
    "claude": (".claude.json", ("mcpServers",)),
    "codex": (".codex/config.toml", ("mcp_servers",)),
    "opencode": (".config/opencode2/opencode/opencode.jsonc", ("mcp", "servers")),
    "amp": (".config/amp/settings.json", ("amp.mcpServers",)),
}


def render(agent, server):
    if server["transport"] == "stdio":
        if agent == "opencode":
            return {
                "type": "local",
                "command": [server["command"], *server["args"]],
                "environment": server["env"],
            }
        result = {
            "command": server["command"],
            "args": server["args"],
            "env": server["env"],
        }
        if agent in {"claude", "omp"}:
            result["type"] = "stdio"
    else:
        result = {"url": server["url"]}
        if agent in {"claude", "omp", "opencode"}:
            result["type"] = "remote" if agent == "opencode" else "http"
        token = server["bearerTokenEnv"]
        if token:
            if agent == "codex":
                result["bearer_token_env_var"] = token
            else:
                reference = (
                    "{env:" + token + "}" if agent == "opencode" else "${" + token + "}"
                )
                result["headers"] = {"Authorization": "Bearer " + reference}
                if agent == "opencode":
                    result["oauth"] = False
    if agent == "pi":
        result["exposure"] = "codemode"
    return result


def write_atomic(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", dir=path.parent, delete=False
        ) as handle:
            temporary = Path(handle.name)
            os.chmod(temporary, 0o600)
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def reconcile(home, manifest, dry_run=False, detach_store_links=False):
    state_path = home / ".local/state/agents/mcp-managed.json"
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    plans = []
    # Reconcile removed agents too, so disabling a target removes only our entries.
    for agent in sorted(set(manifest["agents"]) | set(state)):
        relative, keys = TARGETS[agent]
        path = home / relative
        if agent == "amp" and path.with_suffix(".jsonc").exists():
            if path.exists():
                raise ValueError(
                    "Both Amp settings.json and settings.jsonc exist; resolve the ambiguity first"
                )
            path = path.with_suffix(".jsonc")
        if path.is_symlink() and not str(path.resolve()).startswith("/nix/store/"):
            raise ValueError(f"Refusing non-Nix config symlink: {path}")
        content = path.read_text() if path.exists() else ""
        try:
            data = (
                (
                    tomlkit.parse(content)
                    if agent == "codex"
                    else json5.loads(content, allow_duplicate_keys=False)
                )
                if content
                else {}
            )
        except ValueError:
            raise ValueError(
                f"Invalid {agent} configuration: {path}. No configs updated."
            ) from None
        desired = {
            name: render(agent, server)
            for name, server in manifest["servers"].items()
            if agent in manifest["agents"]
            and server["enable"]
            and agent not in server["excludeAgents"]
        }
        # On first adoption, catalog names migrate old agent-specific definitions.
        owned = set(state.get(agent, []))
        if agent in manifest["agents"]:
            owned.update(manifest["servers"])
        cursor = data
        for key in keys:
            if key not in cursor:
                cursor[key] = {}
            cursor = cursor[key]
        for name in owned:
            cursor.pop(name, None)
        cursor.update(desired)
        if agent == "pi":
            data["autoEnableCodemode"] = True
        if agent == "omp":
            # OMP can rediscover excluded servers from another client's config.
            disabled = [
                name for name in data.get("disabledServers", []) if name not in owned
            ]
            if agent in manifest["agents"]:
                disabled.extend(sorted(set(manifest["servers"]) - set(desired)))
            data["disabledServers"] = disabled
            if "enabledServers" in data:
                data["enabledServers"] = [
                    name for name in data["enabledServers"] if name not in owned
                ]
        output = (
            tomlkit.dumps(data)
            if agent == "codex"
            else json.dumps(data, indent=2) + "\n"
        )
        managed = sorted(manifest["servers"]) if agent in manifest["agents"] else []
        plans.append((agent, path, content, output, owned, managed))
    if detach_store_links:
        for _, path, old, _, _, _ in plans:
            if path.is_symlink() and not dry_run:
                write_atomic(path, old)
        return
    if dry_run:
        return [
            str(path)
            for _, path, old, new, _, _ in plans
            if old != new or path.is_symlink()
        ]
    if not plans:
        return
    # Retain ownership before updating configs, allowing interrupted runs to retry deletions.
    pending = {agent: sorted(owned) for agent, _, _, _, owned, _ in plans}
    write_atomic(state_path, json.dumps(pending, indent=2) + "\n")
    for _, path, old, new, _, _ in plans:
        if old != new or path.is_symlink():
            write_atomic(path, new)
    write_atomic(
        state_path,
        json.dumps(
            {
                agent: names
                for agent, _, _, _, _, names in plans
                if agent in manifest["agents"]
            },
            indent=2,
        )
        + "\n",
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--detach-store-links", action="store_true")
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    changed = reconcile(
        args.home,
        json.loads(args.manifest.read_text()),
        args.dry_run,
        args.detach_store_links,
    )
    if args.dry_run:
        print(json.dumps({"would_change": changed}))


if __name__ == "__main__":
    main()
