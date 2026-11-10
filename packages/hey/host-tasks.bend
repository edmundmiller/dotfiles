import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-context.bend as Context
import ./privilege.bend as Privilege

type HostTask is Data:
  GarbageCollection{keep_generations: Bool}
  UpgradeMole{}
  CleanOpenCode{}
  DeployHost{host: String, dry: Bool}
  DeployUnas{local: Bool}

def required_home(home: String) -> IO(String):
  match home:
    case SNil{}:
      IO.die(String, 1, "hey: HOME is required for cache cleanup")
    case home:
      IO.pure(String, home)

def collect_garbage(platform: String) -> IO(Unit):
  match platform:
    case "Darwin":
      do IO<Unit>:
        OS.checked(["sudo", "nix-env", "--profile", "/nix/var/nix/profiles/system", "--delete-generations", "old"])
        OS.checked(["sudo", "nix-collect-garbage", "-d"])
        OS.checked(["nix-collect-garbage", "-d"])
    case platform:
      OS.checked(["nix-collect-garbage", "-d"])

def garbage_collection(keep: Bool) -> IO(Unit):
  match keep:
    case True{}:
      OS.checked(["nix-store", "--gc"])
    case False{}:
      do IO<Unit>:
        platform : String <- Posix.platform_name()
        collect_garbage(platform)

def upgrade_mole(platform: String) -> IO(Unit):
  match platform:
    case "Darwin":
      do IO<Unit>:
        Posix.set_environment("HOMEBREW_NO_AUTO_UPDATE", "1")
        Posix.set_environment("HOMEBREW_NO_INSTALL_CLEANUP", "1")
        Posix.set_environment("HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK", "1")
        OS.checked(["/opt/homebrew/bin/brew", "upgrade", "homebrew/core/mole"])
    case platform:
      IO.die(Unit, 1, "Mole upgrade is only supported on macOS")

def deploy_host(ctx: Context.TaskContext, host: String, dry: Bool) -> IO(Unit):
  match ctx dry:
    case Context.TaskContext{root, hostname, platform} True{}:
      do IO<Unit>:
        Posix.change_directory(root)
        OS.checked(["nix", "run", ".#deploy-rs", "--", ".#" ++ host, "--dry-activate"])
    case Context.TaskContext{root, hostname, platform} False{}:
      do IO<Unit>:
        Posix.change_directory(root)
        OS.checked(["nix", "run", ".#deploy-rs", "--", ".#" ++ host])

def deploy_unas_local(host: String) -> IO(Unit):
  match host:
    case "unas":
      Privilege.run_privileged(["sudo", "-n", "nixos-rebuild", "switch", "--flake", ".#unas", "--show-trace", "--accept-flake-config", "--max-jobs", "2"])
    case host:
      IO.die(Unit, 1, "hey unas local must run on the installed UNAS host")

def deploy_unas(ctx: Context.TaskContext, local: Bool) -> IO(Unit):
  match ctx local:
    case Context.TaskContext{root, hostname, platform} False{}:
      do IO<Unit>:
        Posix.change_directory(root)
        OS.checked(["nix", "run", ".#deploy-rs", "--", ".#unas", "--skip-checks"])
    case Context.TaskContext{root, hostname, platform} True{}:
      do IO<Unit>:
        Posix.change_directory(root)
        host : String <- Posix.host_name()
        deploy_unas_local(host)

def execute_host_task(task: HostTask) -> IO(Unit):
  match task:
    case GarbageCollection{keep}:
      garbage_collection(keep)
    case UpgradeMole{}:
      do IO<Unit>:
        platform : String <- Posix.platform_name()
        upgrade_mole(platform)
    case CleanOpenCode{}:
      do IO<Unit>:
        home_value : String <- OS.env("HOME")
        +home : String <- required_home(home_value)
        OS.checked(["rm", "-rf", "--", home ++ "/.cache/opencode/node_modules"])
        OS.checked(["rm", "-f", "--", home ++ "/.cache/opencode/bun.lock"])
    case DeployHost{host, dry}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        deploy_host(ctx, host, dry)
    case DeployUnas{local}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        deploy_unas(ctx, local)
