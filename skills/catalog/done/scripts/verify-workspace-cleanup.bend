import Base
import ./common.bend as C
import ./policy.bend as Policy

def directory(path: String, label: String) -> C.Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : C.Command <- C.run("sh", ["-c", "cd -- \"$1\" && pwd -P", "done", path], "")
    C.checked(result, "cleanup refused: " ++ label ++ " directory is inaccessible")

def verify(active: String, candidate: String) -> C.Task(String):
  do C.Task<String>:
    +active_path : String <- directory(active, "active")
    +candidate_path : String <- directory(candidate, "candidate")
    C.require(Bool.not(String.eq(candidate_path, "/")), "cleanup refused: candidate directory is root")
    C.require(Policy.cleanup_safe(active_path, candidate_path), "cleanup deferred: candidate contains the active agent directory")
    return "cleanup safe: active=" ++ active_path ++ " candidate=" ++ candidate_path

def arguments(args: List<String>) -> C.Task(String):
  match args:
    case Con{active, Con{candidate, Nil{}}}:
      verify(active, candidate)
    case _:
      C.Task.fail(String, "usage: verify-workspace-cleanup.bend <active-directory> <candidate-directory>")

def finish(result: Result<&1, &1, String, String>) -> IO(Unit):
  match result:
    case Done{text}:
      IO.print(text)
    case Fail{+error}:
      IO.die(Unit, C.choose(U32, String.starts_with(error, "usage:"), 64, C.choose(U32, String.starts_with(error, "cleanup deferred"), 1, 2)), error)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    result : Result<&1, &1, String, String> <- arguments(List.tail(&1, String, args))
    finish(result)
