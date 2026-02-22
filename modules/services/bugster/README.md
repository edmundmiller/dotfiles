# Bugster — Dagster Code Location

Syncs GitHub/Jira/Linear issues into Obsidian TaskNotes via dlt pipelines, running as a dagster code location.

## Enable

```nix
modules.services.bugster = {
  enable = true;
  environmentFile = config.age.secrets.bugster-env.path;
  sources = [
    { type = "github"; name = "personal"; tokenEnv = "GITHUB_TOKEN"; username = "edmundmiller"; }
    { type = "linear"; name = "work"; tokenEnv = "LINEAR_TOKEN"; }
  ];
};
```

## Architecture

```
bugster-setup.service (oneshot)
  ├── git clone/pull edmundmiller/bugster → /var/lib/dagster/bugster
  └── generates bugster.toml from Nix options

dagster-code-bugster.service
  ├── uv sync --frozen (install Python deps)
  └── dagster code-server start -m bugster.definitions -p 4000

dagster-webserver.service ──→ workspace.yaml → grpc://localhost:4000
dagster-daemon.service ────→ workspace.yaml → grpc://localhost:4000
```

## Secrets

Create `hosts/nuc/secrets/bugster-env.age` with:

```
GITHUB_TOKEN=ghp_xxx
LINEAR_TOKEN=lin_api_xxx
```

Override owner in host config:

```nix
age.secrets.bugster-env.owner = "dagster";
```

## Updating Bugster

The `bugster-setup` service pulls the latest `main` branch on every start. To update:

```bash
# On the NUC
sudo systemctl restart bugster-setup dagster-code-bugster
```

## Configuration

| Option                | Default                                   | Description           |
| --------------------- | ----------------------------------------- | --------------------- |
| `gitUrl`              | `git@github.com:edmundmiller/bugster.git` | Repo SSH URL          |
| `gitBranch`           | `main`                                    | Branch to track       |
| `port`                | `4000`                                    | gRPC code server port |
| `dataDir`             | `/var/lib/dagster/bugster`                | Working directory     |
| `tasknotes.vaultPath` | `/home/emiller/obsidian-vault`            | Obsidian vault        |
| `tasknotes.tasksDir`  | `00_Inbox/Tasks/Bugster`                  | TaskNotes output dir  |

## Troubleshooting

**Code server fails to start:**

```bash
journalctl -u dagster-code-bugster -f
# Check if uv sync succeeded
```

**Git clone fails:**

```bash
journalctl -u bugster-setup
# Verify SSH key: /home/emiller/.ssh/id_ed25519
```

**Token issues:**

```bash
# Check secret is decrypted
cat /run/agenix/bugster-env
```
