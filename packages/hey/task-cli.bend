import Base

def share_arguments(args: List<String>) -> List<&2, String>:
  match args:
    case Nil{}:
      Nil{}
    case head <> rest:
      head <> share_arguments(rest)

def wants_help(args: List<&2, String>) -> Bool:
  match args:
    case "--help" <> rest:
      True{}
    case "-h" <> rest:
      True{}
    case arg <> rest:
      wants_help(rest)
    case Nil{}:
      False{}

def nuc_snapshot_parameters() -> String:
  "  mode  dry-activate (default), test, switch, build, vm or validate\n  configuration  NUC configuration, default nuc"

def task_parameters(name: String) -> String:
  match name:
    case "search":
      "  query  Search expression"
    case "shell":
      "  package  nixpkgs package"
    case "update":
      "  inputs  Optional flake inputs"
    case "rebuild":
      "  action  Rebuild action, default switch\n  args  Rebuild arguments"
    case "deploy":
      "  host  Target host"
    case "deploy:dry":
      "  host  Target host"
    case "unas":
      "  mode  remote or local"
    case "nuc":
      "  mode  auto (default), local, wt, worktree, dry-activate, test, switch, build, vm, validate or revision\n  worktree_mode  Action or exact revision, default switch"
    case "nuc:worktree":
      nuc_snapshot_parameters()
    case "nuc:logs":
      "  unit  Optional systemd unit\n  lines  Number of entries, default 50"
    case "nuc:service":
      "  service  Systemd service"
    case "gc":
      "  --keep-generations  Keep system generations"
    case "pi:update":
      "  version  Exact Pi release"
    case "login:betty":
      "  (no parameters)"
    case "login:scintillate":
      "  (no parameters)"
    case "agents:prepare":
      "  --workspace  Local agents-workspace checkout; prepares pin changes without publication or deployment"
    case "hermes:local":
      "  --smoke-only  Check local Hermes without rebuilding the host"
    case "xcode:setup":
      "  app  Installed Xcode.app\n  --apply  Prepare Metal and select Xcode\n  --prompt-admin  Allow an administrator dialog\n  --install-to  Move the app without replacing an existing destination"
    case "setup-caches":
      "  --apply  Append the approved cache block and restart nix-daemon after confirmation"
    case "ergodox:flash":
      "  hex  Optional firmware file"
    case "unas:recover":
      "  root  Mounted root\n  system  Built system"
    case name:
      "  args  Arguments passed to the task"
