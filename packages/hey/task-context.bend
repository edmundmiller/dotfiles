import Base
import ./os.bend as OS
import ./posix.bend as Posix

type TaskContext is Data:
  TaskContext{root: String, host: String, platform: String}

def default_value(value: String, fallback: String) -> String:
  match value:
    case SNil{}:
      fallback
    case value:
      value

def host_alias(host: String) -> String:
  match host:
    case "Mac":
      "MacTraitor-Pro"
    case "mactraitor-pro":
      "MacTraitor-Pro"
    case "L19W56QXR4":
      "Seqeratop"
    case host:
      host

def root_found(fuel: Nat, +path: String, found: Bool) -> IO(String):
  match fuel found:
    case fuel True{}:
      IO.pure(String, path)
    case 0n False{}:
      IO.die(String, 1, "Run this task in the dotfiles checkout, or use mise --cd <checkout> run <task>")
    case 1n+rest False{}:
      do IO<String>:
        +parent : String <- OS.output(["dirname", path])
        present : Bool <- Posix.path_exists(parent ++ "/flake.nix")
        root_found(rest, parent, present)

def find_root(selected: String) -> IO(String):
  match selected:
    case SNil{}:
      do IO<String>:
        +cwd : String <- Posix.current_directory()
        found : Bool <- Posix.path_exists(cwd ++ "/flake.nix")
        root_found(256n, cwd, found)
    case root:
      IO.pure(String, root)

def task_context() -> IO(TaskContext):
  do IO<TaskContext>:
    selected : String <- OS.env("MISE_PROJECT_ROOT")
    root : String <- find_root(selected)
    hostname : String <- Posix.host_name()
    override : String <- OS.env("FLAKE_HOST")
    platform : String <- Posix.platform_name()
    return TaskContext{root, default_value(override, host_alias(hostname)), platform}
