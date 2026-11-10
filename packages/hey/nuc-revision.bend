import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./nuc-cli.bend as NucCli
import ./nuc-plan.bend as Plan
import ./nuc-effects.bend as Effects
import ./repository-policy.bend as Repository

type HomeAssistantMode is Data:
  PreserveHomeAssistant{}
  RestartHomeAssistant{authority: String}

def agents_revision(root: String, revision: Repository.GitRevision) -> IO(Repository.GitRevision):
  match revision:
    case Repository.GitRevision{value}:
      do IO<Repository.GitRevision>:
        lock : String <- OS.output(["git", "-C", root, "show", value ++ ":flake.lock"])
        temporary : String <- Posix.temporary_directory()
        +path : String = temporary ++ "/flake.lock"
        Posix.write_text(path, lock)
        agents : String <- OS.output(["jq", "-er", ".nodes as $nodes | $nodes[$nodes[.root].inputs[\"agents-workspace\"]].locked.rev | select(type == \"string\" and length == 40 and test(\"^[0-9a-f]{40}$\"))", path])
        Repository.require_revision(agents)

def restart_decision(guard: NucCli.RevisionGuard, authority: String, empty: Bool) -> IO(HomeAssistantMode):
  match guard empty:
    case NucCli.ExactMain{} False{}:
      IO.pure(HomeAssistantMode, RestartHomeAssistant{authority})
    case guard empty:
      IO.die(HomeAssistantMode, 1, "HA restart required: ask Edmund to approve this exact deployment's HA downtime; provide NUC_HA_RESTART_AUTHORITY with a manual exact-main deployment")

def restart_mode(guard: NucCli.RevisionGuard, +authority: String) -> IO(HomeAssistantMode):
  restart_decision(guard, authority, String.is_empty(authority))

# HA is preserved unless NUC_PRESERVE_HA explicitly opts out with exact-main restart authority.
def home_assistant_mode(guard: NucCli.RevisionGuard, preserve: String, authority: String) -> IO(HomeAssistantMode):
  match preserve:
    case SNil{}:
      IO.pure(HomeAssistantMode, PreserveHomeAssistant{})
    case "true":
      IO.pure(HomeAssistantMode, PreserveHomeAssistant{})
    case preserve:
      restart_mode(guard, authority)

def home_assistant_flag(mode: HomeAssistantMode) -> String:
  match mode:
    case PreserveHomeAssistant{}:
      "--nuc-deploy-preserve-home-assistant"
    case RestartHomeAssistant{authority}:
      "--nuc-deploy-ha-restart-authority=" ++ authority

def guard_flag(guard: NucCli.RevisionGuard, revision: String) -> String:
  match guard:
    case NucCli.ExactMain{}:
      "--nuc-deploy-expected-main=" ++ revision
    case NucCli.PublishedMain{}:
      "--nuc-deploy-published=" ++ revision

# Arguments for the published guard wrapper the worker materializes on the host.
def deployment_argv(guard: NucCli.RevisionGuard, +revision: String) -> List<&2, String>:
  [guard_flag(guard, revision), "--nuc-deploy-source-head=" ++ revision, "--nuc-deploy-source-base=" ++ revision, "--nuc-deploy-source-owner=github-nuc-deploy", "nixos-rebuild", "switch", "--flake", "github:edmundmiller/dotfiles/" ++ revision ++ "#nuc", "--show-trace", "--accept-flake-config", "--max-jobs", "1"]

def revision_command(root: String, dotfiles: Repository.GitRevision, agents: Repository.GitRevision, guard: NucCli.RevisionGuard, source: Repository.GitRevision, mode: HomeAssistantMode) -> IO(String):
  match dotfiles agents source:
    case Repository.GitRevision{+revision} Repository.GitRevision{agents_revision} Repository.GitRevision{guard_revision}:
      Effects.worker_command(root, "nuc-revision.sh", List.append(&2, String, ["nuc", "dotfiles=" ++ revision ++ ";agents-workspace=" ++ agents_revision, "tailscaled.service", "sshd.service", "nixos-upgrade.timer", "Linux", Plan.privilege_program(), guard_revision, home_assistant_flag(mode), revision], deployment_argv(guard, revision)))

def deploy_revision(+root: String, +revision: Repository.GitRevision, +guard: NucCli.RevisionGuard) -> IO(Unit):
  do IO<Unit>:
    preserve : String <- OS.env("NUC_PRESERVE_HA")
    authority : String <- OS.env("NUC_HA_RESTART_AUTHORITY")
    mode : HomeAssistantMode <- home_assistant_mode(guard, preserve, String.trim(authority))
    agents : Repository.GitRevision <- agents_revision(root, revision)
    # Use the dispatching source's guard even if rollout selects an older target.
    head : String <- OS.output(["git", "-C", root, "rev-parse", "HEAD"])
    source : Repository.GitRevision <- Repository.require_revision(head)
    command : String <- revision_command(root, revision, agents, guard, source, mode)
    OS.checked(["tailscale", "ssh", "emiller@nuc.cinnamon-rooster.ts.net", command])
