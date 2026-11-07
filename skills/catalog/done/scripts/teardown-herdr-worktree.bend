import Base
import ./common.bend as C
import ./policy.bend as Policy

def match_path(path: String, candidate: String) -> C.Task(Nat):
  match path:
    case SNil{}:
      C.Task.pure(Nat, 0n)
    case SCon{h, t}:
      do IO<Result<&1, &1, String, Nat>>:
        resolved : C.Command <- C.run("sh", ["-c", "cd -- \"$1\" && pwd -P", "done", SCon{h, t}], "")
        C.Task.pure(Nat, C.choose(Nat, String.eq(C.optional(resolved), candidate), 1n, 0n))

def matches(entries: List<&2, String>, +candidate: String, +workspace: String) -> C.Task(Nat):
  match entries:
    case Nil{}:
      C.Task.pure(Nat, 0n)
    case Con{entry, tail}:
      do C.Task<Nat>:
        eligible : String <- C.output("jq", ["-r", "select(type == \"object\" and (.path | type == \"string\") and .open_workspace_id == " ++ C.quote(workspace) ++ " and .is_linked_worktree == true and .is_prunable == false) | .path"], entry)
        here : Nat <- match_path(eligible, candidate)
        rest : Nat <- matches(tail, candidate, workspace)
        return Nat.add(here, rest)

def prepare(path: String) -> C.Task(String & String):
  do C.Task<String & String>:
    environment : String <- C.env("HERDR_ENV")
    C.require(String.eq(environment, "1"), "HERDR_ENV=1 is required")
    +workspace : String <- C.env("HERDR_WORKSPACE_ID")
    C.require(C.nonempty(workspace), "HERDR_WORKSPACE_ID is required")
    +candidate : String <- C.real_directory(path)
    active : String <- C.real_directory(".")
    C.require(Bool.not(Policy.cleanup_safe(active, candidate)), "active directory is outside the recorded task root")
    +root : String <- C.git_output(candidate, ["rev-parse", "--show-toplevel"])
    resolved_root : String <- C.real_directory(root)
    C.require(String.eq(resolved_root, candidate), "recorded task root is not the Git worktree root")
    status : String <- C.git_output(candidate, ["status", "--porcelain=v1", "--untracked-files=all"])
    C.require(String.is_empty(status), "recorded task worktree is not clean")
    +configured : String <- C.env("HERDR_BIN_PATH")
    +herdr : String = C.choose(String, C.nonempty(configured), configured, "herdr")
    response : String <- C.output(herdr, ["worktree", "list", "--workspace", workspace, "--json"], "")
    entries_json : String <- C.json_query(response, ".result | if type == \"object\" and .type == \"worktree_list\" and (.worktrees | type == \"array\") then .worktrees else error(\"invalid provenance\") end")
    entries : List<&2, String> <- C.json_items(entries_json)
    count : Nat <- matches(entries, candidate, workspace)
    C.require(Nat.is_eq(count, 1n), "Herdr workspace does not own the recorded task worktree")
    return (herdr, workspace)

def arguments(args: List<String>) -> C.Task(String & String):
  match args:
    case Con{path, Nil{}}:
      prepare(path)
    case _:
      C.Task.fail(String & String, "usage: teardown-herdr-worktree.bend <recorded-task-root>")

def removed(result: C.Command) -> IO(Unit):
  C.Command{code, out, err} = result
  do IO<Unit>:
    IO.write(out)
    IO.print_err(err)
    IO.exit(code)

def finish(result: Result<&1, &1, String, String & String>) -> IO(Unit):
  match result:
    case Fail{message}:
      IO.die(Unit, 1, "cleanup deferred: " ++ message)
    case Done{(herdr, workspace)}:
      do IO<Unit>:
        result : C.Command <- C.run(herdr, ["worktree", "remove", "--workspace", workspace, "--json"], "")
        removed(result)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    result : Result<&1, &1, String, String & String> <- arguments(List.tail(&1, String, args))
    finish(result)
