import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./nuc-policy.bend as Policy
import ./nuc-observations.bend as Observations
import ./nuc-plan.bend as Plan
import ./nuc-effects.bend as Effects
import ./nuc-snapshot.bend as Snapshot
import ./nuc-validation-request.bend as Validation

def description_target(description: Snapshot.SnapshotDescription) -> Effects.ExecutionTarget:
  match description:
    case Snapshot.SnapshotDescription{Snapshot.SnapshotIdentity{directory, user, target, intent}, digest, release}:
      target

def description_identity(description: Snapshot.SnapshotDescription) -> Snapshot.SnapshotIdentity:
  match description:
    case Snapshot.SnapshotDescription{identity, digest, release}:
      identity

def lifecycle_command(root: String, description: Snapshot.SnapshotDescription, argv: List<&2, String>) -> IO(String):
  match description:
    case Snapshot.SnapshotDescription{Snapshot.SnapshotIdentity{directory, user, target, intent}, digest, release}:
      Effects.worker_command(root, "nuc-lifecycle.sh", List.append(&2, String, [directory, release], argv))

def execute_lifecycle(root: String, +description: Snapshot.SnapshotDescription, lease: Snapshot.SnapshotLease, argv: List<&2, String>, postcheck: Plan.PostDeployCheck) -> IO(Unit):
  do IO<Unit>:
    +target : Effects.ExecutionTarget = description_target(description)
    command : String <- lifecycle_command(root, description, argv)
    Snapshot.handoff_lease(lease)
    Effects.checked_shell(target, command)
    Observations.post_deploy_check(target, postcheck)

def execute_validation(root: String, +description: Snapshot.SnapshotDescription, lease: Snapshot.SnapshotLease) -> IO(Unit):
  do IO<Unit>:
    target : Effects.ExecutionTarget = description_target(description)
    command : String <- Validation.prepare_submission(root, description)
    Snapshot.handoff_lease(lease)
    Effects.checked_shell(target, command)

def execute_operation(root: String, description: Snapshot.SnapshotDescription, lease: Snapshot.SnapshotLease, operation: Plan.SnapshotOperation) -> IO(Unit):
  match operation:
    case Plan.RunSnapshot{argv, postcheck}:
      execute_lifecycle(root, description, lease, argv, postcheck)
    case Plan.ValidateSnapshot{}:
      execute_validation(root, description, lease)

def prepared_operation(description: Snapshot.SnapshotDescription, configuration: Policy.NucConfiguration, stale: Bool) -> Plan.SnapshotOperation:
  match description:
    case Snapshot.SnapshotDescription{Snapshot.SnapshotIdentity{directory, user, target, intent}, digest, release}:
      Plan.snapshot_operation(intent, directory, configuration, stale)

def execute_prepared(root: String, configuration: Policy.NucConfiguration, stale: Bool, prepared: Snapshot.PreparedSnapshot) -> IO(Unit):
  match prepared:
    case Snapshot.PreparedSnapshot{+description, lease}:
      execute_operation(root, description, lease, prepared_operation(description, configuration, stale))

def announce_snapshot(identity: Snapshot.SnapshotIdentity) -> IO(Unit):
  match identity:
    case Snapshot.SnapshotIdentity{directory, user, target, intent}:
      IO.print("NUC_WORKTREE_REMOTE_DIR=" ++ directory)

def execute_snapshot(+root: String, user: String, +target: Effects.ExecutionTarget, intent: Policy.DeploymentIntent, configuration: Policy.NucConfiguration) -> IO(Unit):
  do IO<Unit>:
    Effects.verify_target_identity(target)
    +identity : Snapshot.SnapshotIdentity <- Snapshot.snapshot_identity(user, target, intent)
    announce_snapshot(identity)
    prepared : Snapshot.PreparedSnapshot <- Snapshot.prepare_snapshot(root, identity)
    allowed : String <- OS.env("NUC_DEPLOY_ALLOW_STALE")
    execute_prepared(root, configuration, String.eq(allowed, "1"), prepared)
