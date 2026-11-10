import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./remote-arguments.bend as Remote
import ./task-text.bend as Text

type ExecutionTarget is Data:
  LocalTarget{}
  RemoteNuc{}

def literal_argv(target: ExecutionTarget, args: List<&2, String>) -> List<String>:
  match target:
    case LocalTarget{}:
      OS.linear_arguments(args)
    case RemoteNuc{}:
      ["ssh", "nuc", Remote.quote_command(args)]

def shell_command(script: String, args: List<&2, String>) -> String:
  Remote.quote_command(List.append(&2, String, ["bash", "-c", script, "--"], args))

def run_command(target: ExecutionTarget, args: List<&2, String>, capture: Bool) -> IO(OS.ProcessResult):
  OS.run(literal_argv(target, args), capture)

def checked_command(target: ExecutionTarget, args: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    result : OS.ProcessResult <- run_command(target, args, False{})
    OS.check(result)

def output_command(target: ExecutionTarget, args: List<&2, String>) -> IO(String):
  do IO<String>:
    result : OS.ProcessResult <- run_command(target, args, True{})
    OS.output_value(result)

def shell_argv(target: ExecutionTarget, command: String) -> List<String>:
  literal_argv(target, ["bash", "-c", command])

def checked_shell(target: ExecutionTarget, command: String) -> IO(Unit):
  OS.checked(shell_argv(target, command))

def interactive_shell(target: ExecutionTarget, command: String) -> IO(Unit):
  match target:
    case LocalTarget{}:
      OS.checked(["bash", "-c", command])
    case RemoteNuc{}:
      OS.checked(["ssh", "-t", "nuc", command])

def checked_input(target: ExecutionTarget, args: List<&2, String>, source: String) -> IO(Unit):
  do IO<Unit>:
    result : OS.ProcessResult <- OS.run_with_input(literal_argv(target, args), False{}, source)
    OS.check(result)

def load_worker(root: String, name: String) -> IO(String):
  Posix.read_text(root ++ "/packages/hey/workers/" ++ name)

def worker_command(root: String, name: String, args: List<&2, String>) -> IO(String):
  do IO<String>:
    script : String <- load_worker(root, name)
    return shell_command(script, args)

def encode_program(script: String) -> IO(String):
  do IO<String>:
    directory : String <- Posix.temporary_directory()
    +path : String = directory ++ "/program"
    Posix.write_text(path, script)
    result : OS.ProcessResult <- OS.run_with_input(["base64"], True{}, path)
    encoded : String <- OS.output_value(result)
    return Text.replace_task_text(encoded, "\n", "")

def identity_result(hostname: String, platform: String) -> IO(Unit):
  match hostname platform:
    case "nuc" "Linux":
      IO.pure(Unit, Unit{})
    case hostname platform:
      IO.die(Unit, 1, "NUC target identity check failed; expected nuc on Linux before any snapshot or deployment operation")

def verify_target_identity(target: ExecutionTarget) -> IO(Unit):
  do IO<Unit>:
    +shared : ExecutionTarget = target
    +hostname : String <- output_command(shared, ["hostname", "-s"])
    platform : String <- output_command(shared, ["uname", "-s"])
    checked_command(shared, ["uname", "-a"])
    IO.print("hostname=" ++ hostname)
    identity_result(hostname, platform)
