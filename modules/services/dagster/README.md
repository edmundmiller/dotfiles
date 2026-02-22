# Dagster NixOS Module

Data orchestration platform. Runs the Dagster webserver, daemon, and connects to code location servers.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐
│ dagster-webserver │     │  dagster-daemon   │
│   (UI + GraphQL) │     │ (schedules/sensors│
│     port 3000    │     │   run queue)      │
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
    ┌───────────────┼──────────────┐
    │               │              │
┌───▼───┐    ┌──────▼───┐   ┌─────▼────┐
│ Postgres│   │Code Loc 1│   │Code Loc N│
│(storage)│   │ gRPC:4000│   │ gRPC:400N│
└─────────┘   └──────────┘   └──────────┘
```

## Enable

```nix
# hosts/nuc/default.nix
modules.services.dagster = {
  enable = true;
  webserver.host = "0.0.0.0";  # listen on all interfaces
};
```

## Package

Built from `packages/dagster.nix` — bundles dagster-core, webserver, graphql, postgres, pipes, shared into a single Python env. Exposed as `pkgs.my.dagster`. Override with:

```nix
modules.services.dagster.package = myCustomDagsterEnv;
```

## Code Locations

### gRPC server (recommended for production)

```nix
codeLocations = [
  { type = "grpc"; host = "localhost"; port = 4000; }
  { type = "grpc"; host = "localhost"; port = 4001; }
];
```

### Python module

```nix
codeLocations = [
  { type = "module"; module = "my_dagster_project"; }
];
```

### Python file

```nix
codeLocations = [
  { type = "file"; file = "/opt/dagster/code/definitions.py"; }
];
```

## Run Launcher Options

- `"default"` — runs execute in the daemon process (simple, for dev/small workloads)
- `"docker"` — runs launch in new Docker containers (requires `dagster-docker` pip package)

## Run Coordinator Options

- `"default"` — runs launch immediately
- `"queued"` — runs queue through the daemon (recommended for production)

## Tailscale Access

```nix
modules.services.dagster = {
  enable = true;
  tailscaleService = {
    enable = true;
    serviceName = "dagster";
  };
};
```

## Healthcheck

```nix
modules.services.dagster.healthcheck = {
  enable = true;
  pingUrl = "https://hc-ping.com/your-uuid";
};
```

## Full Example

```nix
modules.services.dagster = {
  enable = true;
  webserver.host = "0.0.0.0";
  webserver.port = 3000;

  runCoordinator = "queued";
  maxConcurrentRuns = 5;

  runRetries.maxRetries = 2;
  retentionDays = 14;

  runMonitoring = {
    enable = true;
    pollInterval = 60;
  };

  codeLocations = [
    { type = "grpc"; host = "localhost"; port = 4000; }
  ];

  tailscaleService.enable = true;
  healthcheck = {
    enable = true;
    pingUrl = "https://hc-ping.com/xxx";
  };
};
```
