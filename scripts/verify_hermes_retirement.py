#!/usr/bin/env python3
"""Read back a retired NUC Hermes deployment without changing runtime state."""

import json
from pathlib import Path
import subprocess
import sys
from urllib.request import Request, urlopen


def output(*command):
    return subprocess.check_output(
        command, text=True, stderr=subprocess.PIPE, timeout=300
    )


def main():
    check = "active revision"
    try:
        revision = output("nixos-version", "--configuration-revision").strip()
        if not revision.startswith(f"dotfiles={sys.argv[1]};"):
            raise ValueError("Active revision does not match the inspected source")
        check = "declared service selection"
        enabled = json.loads(output(
            "nix-private-github", "nix", "eval", "--json", "--accept-flake-config",
            "--no-write-lock-file",
            f"github:edmundmiller/dotfiles/{sys.argv[1]}#nixosConfigurations.nuc.config.modules.services.hermes.enable",
        ))
        if enabled is True:
            print(json.dumps({"hermesRetirement": "not-applicable"}))
            return 0
        if enabled is not False:
            raise ValueError("Invalid enable setting")

        check = "retired units"
        patterns = ("hermes-*", "buzz-hermes-*", "buzz-presence-*")
        active = output(
            "systemctl", "list-units", "--no-legend", "--plain", "--no-pager",
            "--state=active,activating,reloading,deactivating", *patterns,
        )
        if active.strip():
            raise ValueError("Retired units are still running")
        installed = output(
            "systemctl", "list-unit-files", "--no-legend", "--no-pager", *patterns,
        )
        if any(line.split()[1] in {"enabled", "enabled-runtime", "linked", "linked-runtime"}
               for line in installed.splitlines() if line.strip()):
            raise ValueError("Retired units remain enabled")

        check = "Hermes exposure"
        serve = json.loads(output("tailscale", "serve", "status", "--json"))
        if '"svc:hermes"' in json.dumps(serve):
            raise ValueError("Hermes Serve mapping remains")
        for line in output("ss", "-H", "-ltn").splitlines():
            if line.split()[3].rsplit(":", 1)[-1] in {"8642", "8787", "9121"}:
                raise ValueError("A retired Hermes port remains open")

        check = "retained homes and backup timer"
        homes = [Path("/var/lib/hermes/.hermes")] + [
            Path(f"/var/lib/hermes-{profile}/.hermes")
            for profile in ("amosburton", "anne", "betty", "finn", "orchestrator", "scintillate")
        ]
        if not all(home.is_dir() for home in homes):
            raise ValueError("A retained home is missing")
        output("systemctl", "is-active", "--quiet", "restic-backups-hermes-profile-state.timer")

        for service in (
            "home-assistant.service",
            "podman-music-assistant.service", "amp-nascent-manuscript-runner.service",
            "mill-docs-agents-tailscale-serve.service",
        ):
            check = f"surviving service: {service}"
            output("systemctl", "is-active", "--quiet", service)

        check = "live HA service registry"
        token = Path("/run/agenix/ha-hermes-token").read_text().strip()
        request = Request("http://127.0.0.1:8123/api/services", headers={"Authorization": "Bearer " + token})
        with urlopen(request, timeout=20) as response:
            services = json.load(response)
        if any(item["domain"] == "shell_command" and "hermes_betty_good_morning_dj" in item["services"]
               for item in services):
            raise ValueError("Retired DJ command is registered")
        request = Request("http://127.0.0.1:8123/api/states/script.good_morning", headers={"Authorization": "Bearer " + token})
        with urlopen(request, timeout=20) as response:
            if json.load(response)["entity_id"] != "script.good_morning":
                raise ValueError("Good Morning script is missing")
        check = "unchanged active revision"
        if output("nixos-version", "--configuration-revision").strip() != revision:
            raise ValueError("Active revision changed during verification")
    except Exception:
        print(json.dumps({"hermesRetirement": "failed", "check": check}))
        return 1
    print(json.dumps({"hermesRetirement": "verified", "retainedHomes": len(homes),
                      "backupTimer": "active", "survivingServices": "active",
                      "haDjService": "absent", "goodMorningScript": "present"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
