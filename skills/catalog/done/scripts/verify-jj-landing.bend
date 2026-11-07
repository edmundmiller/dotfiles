import Base
import ./common.bend as C
import ./closeout.bend as Closeout

def remote_url(lines: List<&2, String>, +remote: String) -> String:
  match lines:
    case Nil{}:
      ""
    case Con{line, tail}:
      +parts = List.filter(~String, ~C.nonempty, String.split(line, ' '))
      C.choose(String, String.eq(C.first(parts), remote), C.first(List.tail(&2, String, parts)), remote_url(tail, remote))

def verify(+revision: String, +bookmark: String, +remote: String) -> C.Task(String):
  do C.Task<String>:
    root : String <- Closeout.jj_output(".", ["root"])
    +commit : String <- Closeout.jj_output(".", ["log", "-r", revision, "--no-graph", "-T", "commit_id ++ \"\\n\""])
    C.require(C.nonempty(commit), "task revision is missing")
    conflicts : String <- Closeout.jj_output(".", ["log", "-r", revision ++ " & conflicts()", "--no-graph", "-T", "commit_id ++ \"\\n\""])
    C.require(String.is_empty(conflicts), "task revision has conflicts")
    absent : String <- Closeout.jj_output(".", ["log", "-r", revision ++ " & ~::" ++ bookmark, "--no-graph", "-T", "commit_id ++ \"\\n\""])
    C.require(String.is_empty(absent), "task revision is not contained by default bookmark")
    +local_tip : String <- Closeout.jj_output(".", ["log", "-r", bookmark, "--no-graph", "-T", "commit_id ++ \"\\n\""])
    +tracked_tip : String <- Closeout.jj_output(".", ["log", "-r", bookmark ++ "@" ++ remote, "--no-graph", "-T", "commit_id ++ \"\\n\""])
    remotes : String <- Closeout.jj_output(".", ["git", "remote", "list"])
    +url : String = remote_url(C.lines(remotes), remote)
    C.require(C.nonempty(url), "jj remote not found")
    text : String <- C.git_output(".", ["ls-remote", url, "refs/heads/" ++ bookmark])
    +tip : String = C.first(String.split(C.first(C.lines(text)), '\t'))
    C.require(C.nonempty(local_tip) && C.nonempty(tracked_tip) && C.nonempty(tip), "missing local, tracked, or authoritative remote bookmark tip")
    C.require(String.eq(local_tip, tracked_tip) && String.eq(local_tip, tip), "bookmark mismatch between local, tracked, and authoritative remote tips")
    return "PASS jj landing task=" ++ revision ++ " bookmark=" ++ bookmark ++ " tip=" ++ local_tip ++ " remote=" ++ remote

def arguments(args: List<String>) -> C.Task(String):
  match args:
    case Con{revision, Con{bookmark, Con{remote, Nil{}}}}:
      verify(revision, bookmark, remote)
    case _:
      C.Task.fail(String, "usage: verify-jj-landing.bend TASK_REVISION DEFAULT_BOOKMARK REMOTE")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    result : Result<&1, &1, String, String> <- arguments(List.tail(&1, String, args))
    C.complete(result, 1)
