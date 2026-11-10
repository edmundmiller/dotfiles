import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-context.bend as Context
import ./privilege.bend as Privilege
import ./nuc-policy.bend as Policy
import ./nuc-cli.bend as NucCli
import ./nuc-source.bend as Source
import ./nuc-plan.bend as Plan
import ./nuc-effects.bend as Effects
import ./nuc-observations.bend as Observations
import ./nuc-revision.bend as Revision

def local_source(root: String, intent: Policy.DeploymentIntent, stale: Bool) -> IO(Unit):
  match intent:
    case Policy.ActivateSnapshot{action, source}:
      do IO<Unit>:
        Privilege.run_privileged(OS.linear_arguments(Plan.local_rebuild_command(source, root, stale)))
        Observations.post_deploy_check(Effects.LocalTarget{}, Plan.ObserveServices{})
    case Policy.InspectSnapshot{action, source}:
      IO.die(Unit, 1, "Invalid local NUC activation plan")

def execute_local_checked(+root: String, +hostname: String) -> IO(Unit):
  do IO<Unit>:
    user : String <- Source.snapshot_user()
    source : Policy.SnapshotSource <- Source.observe_source(root, hostname, user)
    intent : Policy.DeploymentIntent <- Policy.authorize_snapshot(Policy.Activate{Policy.SwitchGeneration{}}, source)
    allowed : String <- OS.env("NUC_DEPLOY_ALLOW_STALE")
    local_source(root, intent, String.eq(allowed, "1"))

def execute_local(root: String, hostname: String, platform: String) -> IO(Unit):
  match hostname platform:
    case "nuc" "Linux":
      execute_local_checked(root, "nuc")
    case hostname platform:
      IO.die(Unit, 1, "Local NUC activation requires the actual nuc Linux host")

def delegate_worktree(action: Policy.NucAction) -> IO(Unit):
  OS.checked(["mise", "run", "nuc:worktree", "--", Policy.action_name(action)])

def execute_auto(root: String, hostname: String, platform: String, action: Policy.NucAction) -> IO(Unit):
  match hostname platform action:
    case "nuc" "Linux" Policy.Activate{Policy.SwitchGeneration{}}:
      execute_local_checked(root, "nuc")
    case hostname platform action:
      delegate_worktree(action)

def execute_context(context: Context.TaskContext, request: NucCli.NucTask) -> IO(Unit):
  match context request:
    case Context.TaskContext{root, host, platform} NucCli.LocalNuc{}:
      do IO<Unit>:
        hostname : String <- Posix.host_name()
        execute_local(root, hostname, platform)
    case Context.TaskContext{root, host, platform} NucCli.AutoNuc{action}:
      do IO<Unit>:
        hostname : String <- Posix.host_name()
        execute_auto(root, hostname, platform, action)
    case Context.TaskContext{root, host, platform} NucCli.RevisionNuc{revision}:
      Revision.deploy_revision(root, revision)
    case context NucCli.DelegateWorktree{action}:
      delegate_worktree(action)
    case context NucCli.InvalidNucArguments{}:
      IO.die(Unit, 2, "Invalid NUC task arguments")

def execute_nuc_task(request: NucCli.NucTask) -> IO(Unit):
  match request:
    case NucCli.InvalidNucArguments{}:
      IO.die(Unit, 2, "Usage: hey nuc [auto|local|wt|worktree|dry-activate|test|switch|build|vm|validate|revision <SHA>]; hey nuc-wt [mode] [configuration]")
    case request:
      do IO<Unit>:
        context : Context.TaskContext <- Context.task_context()
        execute_context(context, request)
