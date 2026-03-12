# Dagster NixOS Modules

Shared Dagster OSS control plane plus repo-specific code locations.

## Layout

- `default.nix` — shared Dagster instance
- `bugster.nix` — Bugster code location
- `finances.nix` — Finances code location

## Architecture

```
┌──────────────────┐     ┌──────────────────┐
│ dagster-webserver│     │ dagster-daemon   │
│   UI + GraphQL   │     │ schedules/sensors│
└────────┬─────────┘     └────────┬──────────┘
         │                        │
         └──────────┬─────────────┘
                    │
         ┌──────────▼──────────┐
         │   DAGSTER_HOME      │
         │  dagster.yaml       │
         │  workspace.yaml     │
         └──────────┬──────────┘
                    │
        ┌───────────┴────────────┐
        │                        │
┌───────▼────────┐      ┌────────▼────────┐
│dagster-code-   │      │dagster-code-    │
│bugster         │      │finances         │
│grpc :4000      │      │grpc :4010       │
└────────────────┘      └─────────────────┘
```

This is one Dagster deployment with multiple code locations.

## Enable on NUC

```nix
modules.services = {
  dagster.webserver.port = 3001;

  bugster.enable = true;

  finances-dagster = {
    enable = true;
    opTokenFile = "/etc/opnix-token";
  };
};
```

## Notes

- Prod Dagster OSS normally means one webserver + one daemon + separate code-location processes.
- `workspace.yaml` is generated from `modules.services.dagster.codeLocations`.
- If deploy output and host units disagree, suspect stale deploy-rs eval; retry with `--refresh`.
