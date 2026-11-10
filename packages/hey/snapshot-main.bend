import Base
import ./snapshot-cli.bend as Policy
import ./snapshot-tasks.bend as Tasks
import ./resources.bend as Resources
import ./os.bend as OS
import ./task-cli.bend as Cli
import ./task-context.bend as Context

# Bend 2.0.40 overflows C generation if the parsed action/configuration record
# is captured across this IO bind. Resolve the read-only context first.
def execute_args(args: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    context : Context.TaskContext <- Context.task_context()
    Tasks.execute_snapshot_task(context, Policy.snapshot_task_request(args))

def dispatch_help(args: List<&2, String>, help: Bool) -> IO(Unit):
  match help:
    case True{}:
      IO.print("Usage: hey nuc-wt\n\nParameters:\n" ++ Cli.nuc_snapshot_parameters())
    case False{}:
      execute_args(args)

def dispatch_name(name: String, +args: List<&2, String>) -> IO(Unit):
  match name:
    case "nuc:worktree":
      dispatch_help(args, Cli.wants_help(args))
    case name:
      IO.die(Unit, 2, "hey: native snapshot runner requires nuc:worktree")

def dispatch_task(args: List<String>) -> IO(Unit):
  match args:
    case program <> name <> rest:
      dispatch_name(name, Cli.share_arguments(rest))
    case args:
      IO.die(Unit, 2, "hey: task runner requires a canonical task name")

def main() -> IO(Unit):
  do IO<Unit>:
    OS.validate_task_arguments()
    args : List<String> <- IO.args()
    dispatch_task(args)
    Resources.finish_task(0)
