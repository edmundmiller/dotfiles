import Base

type ProcessResult is Data:
  ProcessResult{status: U32, stdout: String, stderr: String}

def run(argv: List<String>, capture: Bool) -> IO(ProcessResult):
  import "./process.c"

def run_with_environment(argv: List<String>, capture: Bool, name: String, value: String) -> IO(ProcessResult):
  import "./process.c"

def run_without_environment(argv: List<String>, capture: Bool, name: String) -> IO(ProcessResult):
  import "./process.c"

def run_with_input(argv: List<String>, capture: Bool, source: String) -> IO(ProcessResult):
  import "./process.c"

def move_program() -> IO(String):
  import "./toolchain.c"

def environment_value(name: String) -> IO(Maybe<&2, String>):
  import "./environment.c"

def validate_task_arguments() -> IO(Unit):
  import "./environment.c"

def env_value(result: Maybe<&2, String>) -> String:
  match result:
    case Some{value}:
      value
    case None{}:
      ""

def env(name: String) -> IO(String):
  do IO<String>:
    result : Maybe<&2, String> <- environment_value(name)
    return env_value(result)

def required_value(name: String, value: String) -> IO(String):
  match value:
    case SNil{}:
      IO.die(String, 1, "hey: required environment variable is empty: " ++ name)
    case value:
      IO.pure(String, value)

def required_environment(+name: String) -> IO(String):
  do IO<String>:
    value : String <- env(name)
    required_value(name, value)

def check(result: ProcessResult) -> IO(Unit):
  match result:
    case ProcessResult{0, out, err}:
      IO.pure(Unit, Unit{})
    case ProcessResult{status, out, err}:
      IO.die(Unit, status, err)

def linear_arguments(args: List<&2, String>) -> List<String>:
  match args:
    case Nil{}:
      Nil{}
    case Con{head, tail}:
      head <> linear_arguments(tail)

def checked(argv: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : ProcessResult <- run(argv, False{})
    check(result)

def output_value(result: ProcessResult) -> IO(String):
  match result:
    case ProcessResult{0, out, err}:
      IO.pure(String, String.trim(out))
    case ProcessResult{status, out, err}:
      IO.die(String, status, err)

def output(argv: List<String>) -> IO(String):
  do IO<String>:
    result : ProcessResult <- run(argv, True{})
    output_value(result)
