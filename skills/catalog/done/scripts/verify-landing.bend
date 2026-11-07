import Base
import ./common.bend as C

def verify_remote(+branch: String, +remote: String, +local_tip: String) -> C.Task(String):
  match remote:
    case SNil{}:
      C.Task.pure(String, "remote=none\n")
    case SCon{h, t}:
      do C.Task<String>:
        +text : String <- C.git_output(".", ["ls-remote", "--exit-code", remote, "refs/heads/" ++ branch])
        +tip : String = C.first(String.split(C.first(C.lines(text)), '\t'))
        C.require(C.nonempty(tip) && String.eq(local_tip, tip), "landing incomplete: local and authoritative remote tips differ")
        return "remote=" ++ remote ++ "\nremote_tip=" ++ tip ++ "\n"

def verify(+revision: String, +branch: String, remote: String) -> C.Task(String):
  do C.Task<String>:
    +integration : String <- C.git_output(".", ["rev-parse", "--verify", revision ++ "^{commit}"])
    +local_tip : String <- C.git_output(".", ["rev-parse", "--verify", branch ++ "^{commit}"])
    ancestor : String <- C.git_output(".", ["merge-base", "--is-ancestor", integration, local_tip])
    suffix : String <- verify_remote(branch, remote, local_tip)
    return "integration_tip=" ++ integration ++ "\ndefault_branch=" ++ branch ++ "\nlocal_tip=" ++ local_tip ++ "\n" ++ suffix

def dispatch(args: List<String>) -> C.Task(String):
  match args:
    case Con{revision, Con{branch, Nil{}}}:
      verify(revision, branch, "")
    case Con{revision, Con{branch, Con{remote, Nil{}}}}:
      verify(revision, branch, remote)
    case _:
      C.Task.fail(String, "usage: verify-landing.bend <integration-tip> <default-branch> [remote]")

def finish(result: Result<&1, &1, String, String>) -> IO(Unit):
  match result:
    case Done{text}:
      IO.write(text)
    case Fail{+message}:
      IO.die(Unit, C.choose(U32, String.starts_with(message, "usage:"), 64, 1), message)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    result : Result<&1, &1, String, String> <- dispatch(List.tail(&1, String, args))
    finish(result)
