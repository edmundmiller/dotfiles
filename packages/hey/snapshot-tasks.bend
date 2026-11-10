import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-context.bend as Context
import ./repository-policy.bend as Repository
import ./nuc-policy.bend as Policy
import ./snapshot-cli.bend as SnapshotCli
import ./nuc-source.bend as Source
import ./snapshot-worker.bend as Worker
import ./nuc-effects.bend as Effects

def execution_target(action: Policy.NucAction, hostname: String, platform: String) -> Effects.ExecutionTarget:
  match action hostname platform:
    case Policy.Inspect{Policy.ValidateSnapshot{}} "nuc" "Linux":
      Effects.LocalTarget{}
    case action hostname platform:
      Effects.RemoteNuc{}

def execute_worktree(+root: String, +hostname: String, platform: String, action: Policy.NucAction, configuration: Policy.NucConfiguration) -> IO(Unit):
  do IO<Unit>:
    +user : String <- Source.snapshot_user()
    source : Policy.SnapshotSource <- Source.observe_source(root, hostname, user)
    +intent : Policy.DeploymentIntent <- Policy.authorize_snapshot(action, source)
    target : Effects.ExecutionTarget = execution_target(Policy.intent_action(intent), hostname, platform)
    Worker.execute_snapshot(root, user, target, intent, configuration)

def execute_snapshot_context(context: Context.TaskContext, action: Policy.NucAction, configuration: Policy.NucConfiguration) -> IO(Unit):
  match context:
    case Context.TaskContext{root, host, platform}:
      do IO<Unit>:
        hostname : String <- Posix.host_name()
        execute_worktree(root, hostname, platform, action, configuration)

def execute_snapshot_task(context: Context.TaskContext, request: SnapshotCli.SnapshotRequest) -> IO(Unit):
  match request:
    case SnapshotCli.PrepareSnapshot{action, configuration}:
      execute_snapshot_context(context, action, configuration)
    case request:
      IO.die(Unit, 2, "Usage: hey nuc-wt [dry-activate|test|switch|build|vm|validate] [configuration]")
