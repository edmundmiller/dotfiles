import Base
import ./nuc-policy.bend as Policy

type SnapshotRequest is Data:
  PrepareSnapshot{action: Policy.NucAction, configuration: Policy.NucConfiguration}
  InvalidSnapshotArguments{}

def snapshot_request(action: Maybe<&2, Policy.NucAction>, configuration: Maybe<&2, Policy.NucConfiguration>) -> SnapshotRequest:
  match action configuration:
    case Some{operation} Some{target}:
      PrepareSnapshot{operation, target}
    case action configuration:
      InvalidSnapshotArguments{}

def snapshot_task_request(args: List<&2, String>) -> SnapshotRequest:
  match args:
    case Nil{}:
      PrepareSnapshot{Policy.Activate{Policy.DryActivate{}}, Policy.NucConfiguration{"nuc"}}
    case mode <> Nil{}:
      snapshot_request(Policy.parse_action(mode), Some{Policy.NucConfiguration{"nuc"}})
    case mode <> configuration <> Nil{}:
      snapshot_request(Policy.parse_action(mode), Policy.parse_configuration(configuration))
    case args:
      InvalidSnapshotArguments{}
