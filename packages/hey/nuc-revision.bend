import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./nuc-plan.bend as Plan
import ./nuc-effects.bend as Effects
import ./repository-policy.bend as Repository

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

def deployment_argv(+revision: String) -> List<&2, String>:
  [Plan.privilege_program(), "-n", "nix-private-github", "--nuc-deploy-expected-main=" ++ revision, "--nuc-deploy-source-head=" ++ revision, "--nuc-deploy-source-base=" ++ revision, "--nuc-deploy-source-owner=github-nuc-deploy", "nixos-rebuild", "switch", "--flake", "github:edmundmiller/dotfiles/" ++ revision ++ "#nuc", "--show-trace", "--accept-flake-config", "--max-jobs", "1"]

def revision_command(root: String, dotfiles: Repository.GitRevision, agents: Repository.GitRevision) -> IO(String):
  match dotfiles agents:
    case Repository.GitRevision{+revision} Repository.GitRevision{agents_revision}:
      Effects.worker_command(root, "nuc-revision.sh", List.append(&2, String, ["nuc", "dotfiles=" ++ revision ++ ";agents-workspace=" ++ agents_revision, "tailscaled.service", "sshd.service", "nixos-upgrade.timer", "Linux"], deployment_argv(revision)))

def deploy_revision(+root: String, +revision: Repository.GitRevision) -> IO(Unit):
  do IO<Unit>:
    agents : Repository.GitRevision <- agents_revision(root, revision)
    command : String <- revision_command(root, revision, agents)
    OS.checked(["tailscale", "ssh", "emiller@nuc.cinnamon-rooster.ts.net", command])
