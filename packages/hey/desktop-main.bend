import Base
import ./desktop-tasks.bend as Tasks
import ./resources.bend as Resources
import ./os.bend as OS
import ./task-cli.bend as Cli

def dispatch_help(+name: String, args: List<&2, String>, help: Bool) -> IO(Unit):
  match help:
    case True{}:
      IO.print("Usage: hey " ++ name ++ "\n\nParameters:\n" ++ Cli.task_parameters(name))
    case False{}:
      Tasks.execute_desktop_task(Tasks.task_request(name, args))

def dispatch_task(args: List<String>) -> IO(Unit):
  match args:
    case program <> name <> rest:
      +shared = Cli.share_arguments(rest)
      dispatch_help(name, shared, Cli.wants_help(shared))
    case args:
      IO.die(Unit, 2, "hey: task runner requires a canonical task name")

def main() -> IO(Unit):
  do IO<Unit>:
    OS.validate_task_arguments()
    args : List<String> <- IO.args()
    dispatch_task(args)
    Resources.finish_task(0)
