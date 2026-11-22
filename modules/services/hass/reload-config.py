#!/usr/bin/env python3
"""Apply Nix-owned reloadable domains once, retaining uncertain writes for review."""

import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen


DOMAINS = ("automation", "script", "scene")


def api(url, token, path, data=None):
    request = Request(
        url + path,
        data=data,
        headers={
            "Authorization": "Bearer " + token,
            "Content-Type": "application/json",
        },
    )
    with urlopen(request, timeout=25) as response:
        payload = response.read(1048577)
        if len(payload) > 1048576:
            raise ValueError("HA response exceeds the deployment reader limit")
        return json.loads(payload)


def save(path, state):
    temporary = path.with_suffix(".new")
    temporary.write_text(json.dumps(state), encoding="utf-8")
    temporary.replace(path)


def reload_configuration(manifest, state_path, token, url="http://127.0.0.1:8123"):
    if manifest.get("version") != 1 or set(manifest.get("domains", {})) != set(DOMAINS):
        raise ValueError("Unsupported HA deployment manifest")
    desired = manifest["domains"]
    if any(
        value is not None and not re.fullmatch(r"[0-9a-f]{64}", value)
        for value in desired.values()
    ):
        raise ValueError("Invalid HA domain digest")
    state = (
        json.loads(state_path.read_text()) if state_path.exists() else {"applied": {}}
    )
    if state.get("pending"):
        raise ValueError(
            "Previous HA reload outcome is uncertain; inspect it before any manual retry"
        )
    changed = [
        domain for domain in DOMAINS if state["applied"].get(domain) != desired[domain]
    ]
    if not changed:
        return []
    validation = api(url, token, "/api/config/core/check_config", b"{}")
    if not isinstance(validation, dict) or validation.get("result") != "valid":
        raise ValueError("HA rejected configuration; no reload was requested")
    for domain in changed:
        # Reserve before the POST. A lost response or killed process must not
        # become an automatic retry on the next boot or deployment.
        state["pending"] = domain
        save(state_path, state)
        result = api(url, token, f"/api/services/{domain}/reload", b"{}")
        if not isinstance(result, list):
            raise ValueError(
                "Unexpected HA reload response; outcome requires inspection"
            )
        state["applied"][domain] = desired[domain]
        del state["pending"]
        save(state_path, state)
        print(f"ha_config_reload={domain} accepted", flush=True)
    return changed


def main():
    manifest = json.loads(Path(sys.argv[1]).read_text())
    state = Path(os.environ["STATE_DIRECTORY"]) / "applied.json"
    token = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "ha-token").read_text().strip()
    # Only readiness GETs retry. Config checks and reload POSTs never replay.
    deadline = time.monotonic() + 60
    while True:
        try:
            api("http://127.0.0.1:8123", token, "/api/")
            break
        except (OSError, URLError):
            if time.monotonic() >= deadline:
                raise ValueError(
                    "HA API did not become ready; no reload was requested"
                ) from None
            time.sleep(1)
    reload_configuration(manifest, state, token)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError):
        # Do not export server response bodies, configuration or credentials.
        print(
            "HA configuration reload failed; inspect the local pending receipt before retrying. HA was not restarted.",
            file=sys.stderr,
        )
        sys.exit(1)
