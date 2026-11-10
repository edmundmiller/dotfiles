import Base
import ./nuc-policy.bend as Policy
import ./repository-policy.bend as Repository

def privilege_program() -> String:
  "/run/wrappers/bin/sudo"

def revision_value(revision: Repository.GitRevision) -> String:
  match revision:
    case Repository.GitRevision{value}:
      value

def stale_flags(allowed: Bool) -> List<&2, String>:
  match allowed:
    case True{}:
      ["--nuc-deploy-allow-stale"]
    case False{}:
      Nil{}

def source_flags(+source: Policy.SnapshotSource, stale: Bool) -> List<&2, String>:
  List.append(&2, String, ["--nuc-deploy-source-head=" ++ revision_value(Policy.source_head(source)), "--nuc-deploy-source-base=" ++ revision_value(Policy.source_base(source)), "--nuc-deploy-source-owner=" ++ Policy.source_owner(source)], stale_flags(stale))

type PostDeployCheck is Data:
  ObserveServices{}
  NoPostCheck{}

def activation_postcheck(action: Policy.ActivationAction) -> PostDeployCheck:
  match action:
    case Policy.DryActivate{}:
      NoPostCheck{}
    case action:
      ObserveServices{}

type SnapshotOperation is Data:
  RunSnapshot{argv: List<&2, String>, postcheck: PostDeployCheck}
  ValidateSnapshot{}

def rebuild_flags() -> List<&2, String>:
  ["--show-trace", "--accept-flake-config", "--max-jobs", "1"]

def snapshot_operation(intent: Policy.DeploymentIntent, directory: String, configuration: Policy.NucConfiguration, stale: Bool) -> SnapshotOperation:
  match intent configuration:
    case Policy.ActivateSnapshot{+action, clean} Policy.NucConfiguration{target}:
      RunSnapshot{List.concat(&2, String, [[privilege_program(), "nix-private-github"], source_flags(Policy.CommittedSource{clean}, stale), ["nixos-rebuild", Policy.activation_name(action), "--flake", directory ++ "#" ++ target], rebuild_flags()]), activation_postcheck(action)}
    case Policy.InspectSnapshot{Policy.BuildSystem{}, source} Policy.NucConfiguration{target}:
      RunSnapshot{List.append(&2, String, [privilege_program(), "nix-private-github", "nixos-rebuild", "build", "--flake", directory ++ "#" ++ target], rebuild_flags()), NoPostCheck{}}
    case Policy.InspectSnapshot{Policy.BuildVirtualMachine{}, source} Policy.NucConfiguration{target}:
      RunSnapshot{List.append(&2, String, [privilege_program(), "nix-private-github", "nix", "build", directory ++ "#nixosConfigurations." ++ target ++ ".config.system.build.vm"], rebuild_flags()), NoPostCheck{}}
    case Policy.InspectSnapshot{Policy.ValidateSnapshot{}, source} configuration:
      ValidateSnapshot{}

def local_rebuild_command(source: Policy.CleanSource, root: String, stale: Bool) -> List<&2, String>:
  List.concat(&2, String, [["sudo", "nix-private-github"], source_flags(Policy.CommittedSource{source}, stale), ["nixos-rebuild", "--flake", root ++ "#nuc"], rebuild_flags(), ["switch"]])

type ValidationResources is Data:
  ValidationResources{high_gib: U32, maximum_gib: U32, minimum_available_kib: U32, jobs: U32, cores: U32}

def validation_resources() -> ValidationResources:
  ValidationResources{10, 12, 16777216, 1, 2}

def validation_memory_description(resources: ValidationResources) -> String:
  match resources:
    case ValidationResources{high, maximum, available, jobs, cores}:
      "user service: MemoryHigh=" ++ U32.show(high) ++ "G MemoryMax=" ++ U32.show(maximum) ++ "G"

def validation_properties(resources: ValidationResources) -> List<&2, String>:
  match resources:
    case ValidationResources{high, maximum, available, jobs, cores}:
      ["--property=MemoryHigh=" ++ U32.show(high) ++ "G", "--property=MemoryMax=" ++ U32.show(maximum) ++ "G", "--property=OOMPolicy=continue"]

def validation_nix_config(resources: ValidationResources) -> String:
  match resources:
    case ValidationResources{high, maximum, available, jobs, cores}:
      "max-jobs = " ++ U32.show(jobs) ++ "\ncores = " ++ U32.show(cores)

def validation_minimum_kib(resources: ValidationResources) -> String:
  match resources:
    case ValidationResources{high, maximum, available, jobs, cores}:
      U32.show(available)

def validation_meminfo() -> String:
  "/proc/meminfo"

def validation_gates() -> List<&2, String>:
  ["full", "3", "python3", "scripts/validation.py", "--full", "nixos", "4", "python3", "scripts/validation.py", "--platform", "nixos", "flake-check", "5", "nix", "flake", "check", "--keep-going", "-L"]

def validation_unit(directory: String) -> String:
  "nuc-validation-" ++ String.reverse(String.take(String.reverse(directory), 36n)) ++ ".service"
