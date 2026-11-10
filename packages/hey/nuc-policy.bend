import Base
import ./repository-policy.bend as Repository

def snapshot_storage_root() -> String:
  "/tmp"

type ActivationAction is Data:
  DryActivate{}
  TestGeneration{}
  SwitchGeneration{}

type InspectionAction is Data:
  BuildSystem{}
  BuildVirtualMachine{}
  ValidateSnapshot{}

type NucAction is Data:
  Activate{action: ActivationAction}
  Inspect{action: InspectionAction}

type NucConfiguration is Data:
  NucConfiguration{name: String}

def parse_action(mode: String) -> Maybe<&2, NucAction>:
  match mode:
    case "dry-activate":
      Some{Activate{DryActivate{}}}
    case "test":
      Some{Activate{TestGeneration{}}}
    case "switch":
      Some{Activate{SwitchGeneration{}}}
    case "build":
      Some{Inspect{BuildSystem{}}}
    case "vm":
      Some{Inspect{BuildVirtualMachine{}}}
    case "validate":
      Some{Inspect{ValidateSnapshot{}}}
    case mode:
      None{}

def parse_configuration(name: String) -> Maybe<&2, NucConfiguration>:
  match name:
    case "nuc":
      Some{NucConfiguration{"nuc"}}
    case "nuc-buzz-scintillate":
      Some{NucConfiguration{"nuc-buzz-scintillate"}}
    case "nuc-buzz-scintillate-finn":
      Some{NucConfiguration{"nuc-buzz-scintillate-finn"}}
    case "nuc-buzz-scintillate-finn-amosburton":
      Some{NucConfiguration{"nuc-buzz-scintillate-finn-amosburton"}}
    case "nuc-buzz-scintillate-finn-amosburton-anne":
      Some{NucConfiguration{"nuc-buzz-scintillate-finn-amosburton-anne"}}
    case name:
      None{}

def activation_name(action: ActivationAction) -> String:
  match action:
    case DryActivate{}:
      "dry-activate"
    case TestGeneration{}:
      "test"
    case SwitchGeneration{}:
      "switch"

def action_name(action: NucAction) -> String:
  match action:
    case Activate{activation}:
      activation_name(activation)
    case Inspect{BuildSystem{}}:
      "build"
    case Inspect{BuildVirtualMachine{}}:
      "vm"
    case Inspect{ValidateSnapshot{}}:
      "validate"

type CleanSource is Data:
  CleanSource{head: Repository.GitRevision, base: Repository.GitRevision, owner: String}

type SnapshotSource is Data:
  CommittedSource{source: CleanSource}
  WorktreeSource{head: Repository.GitRevision, base: Repository.GitRevision, owner: String}

type DeploymentIntent is Data:
  ActivateSnapshot{action: ActivationAction, source: CleanSource}
  InspectSnapshot{action: InspectionAction, source: SnapshotSource}

def authorize_snapshot(action: NucAction, source: SnapshotSource) -> IO(DeploymentIntent):
  match action source:
    case Activate{activation} CommittedSource{clean}:
      IO.pure(DeploymentIntent, ActivateSnapshot{activation, clean})
    case Activate{activation} WorktreeSource{head, base, owner}:
      IO.die(DeploymentIntent, 1, "NUC activation requires a clean committed source. Use build, vm or validate to inspect dirty snapshots.")
    case Inspect{inspection} source:
      IO.pure(DeploymentIntent, InspectSnapshot{inspection, source})

def source_head(source: SnapshotSource) -> Repository.GitRevision:
  match source:
    case CommittedSource{CleanSource{head, base, owner}}:
      head
    case WorktreeSource{head, base, owner}:
      head

def source_base(source: SnapshotSource) -> Repository.GitRevision:
  match source:
    case CommittedSource{CleanSource{head, base, owner}}:
      base
    case WorktreeSource{head, base, owner}:
      base

def source_owner(source: SnapshotSource) -> String:
  match source:
    case CommittedSource{CleanSource{head, base, owner}}:
      owner
    case WorktreeSource{head, base, owner}:
      owner

def source_revision(source: SnapshotSource) -> String:
  match source:
    case CommittedSource{CleanSource{Repository.GitRevision{head}, base, owner}}:
      head
    case WorktreeSource{Repository.GitRevision{head}, base, owner}:
      head ++ "-dirty"

def source_phase(source: SnapshotSource) -> String:
  match source:
    case CommittedSource{clean}:
      "clean"
    case WorktreeSource{head, base, owner}:
      "dirty"

def intent_source(intent: DeploymentIntent) -> SnapshotSource:
  match intent:
    case ActivateSnapshot{action, clean}:
      CommittedSource{clean}
    case InspectSnapshot{action, source}:
      source

def intent_action(intent: DeploymentIntent) -> NucAction:
  match intent:
    case ActivateSnapshot{action, source}:
      Activate{action}
    case InspectSnapshot{action, source}:
      Inspect{action}
