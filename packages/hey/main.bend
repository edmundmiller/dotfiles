import Base
import ./dispatch.bend as Dispatch

# Native-only POSIX exec, with inherited descriptors and no output capture.
def exec(args: List<List<&2, U32>>) -> IO(Unit):
  import "./exec.c"

def run(args: List<List<&2, U32>>) -> IO(Unit):
  match args:
    case Nil{}:
      exec(Dispatch.arguments(Nil{}))
    case Con{program, rest}:
      exec(Dispatch.arguments(rest))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<List<&2, U32>> <- IO.args_bytes()
    run(args)
