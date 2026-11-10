import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-context.bend as Context
import ./task-text.bend as Text
import ./repository-policy.bend as Repository
import ./system-guards.bend as Guards

type PrepareTask is Data:
  PrepareWorkspace{workspace: String}
  InvalidPrepareArguments{}

def inline_workspace(value: String, recognized: Bool) -> PrepareTask:
  match recognized:
    case True{}:
      PrepareWorkspace{String.drop(value, String.length("--workspace="))}
    case False{}:
      InvalidPrepareArguments{}

def task_request(name: String, args: List<&2, String>) -> PrepareTask:
  match name args:
    case "agents:prepare" Nil{}:
      PrepareWorkspace{""}
    case "agents:prepare" "--workspace" <> path <> Nil{}:
      PrepareWorkspace{path}
    case "agents:prepare" +value <> Nil{}:
      inline_workspace(value, String.starts_with(value, "--workspace="))
    case name args:
      InvalidPrepareArguments{}

def agents_input_prefix() -> String:
  "github:edmundmiller/agents-workspace/"

type PinObservation is Data:
  NoPin{}
  OnePin{revision: String}
  MultiplePins{}

type PinCandidate is Data:
  NotPin{}
  ValidPin{revision: String}
  InvalidPin{}

def candidate_revision(revision: String, valid: Bool) -> PinCandidate:
  match valid:
    case True{}:
      ValidPin{revision}
    case False{}:
      InvalidPin{}

def pin_delimiter(character: Char) -> Bool:
  match character:
    case Chr{34}:
      True{}
    case Chr{39}:
      True{}
    case Chr{63}:
      True{}
    case Chr{35}:
      True{}
    case character:
      Char.is_space(character)

def complete_pin(+revision: String, tail: String) -> PinCandidate:
  match tail:
    case SNil{}:
      candidate_revision(revision, Repository.valid_revision(revision))
    case SCon{head, rest}:
      candidate_revision(revision, Bool.and(Repository.valid_revision(revision), pin_delimiter(head)))

def pin_candidate_if(text: String, prefix: Bool) -> PinCandidate:
  match prefix:
    case True{}:
      +tail : String = String.drop(text, String.length(agents_input_prefix()))
      complete_pin(String.take(tail, 40n), String.drop(tail, 40n))
    case False{}:
      NotPin{}

def pin_candidate(+text: String) -> PinCandidate:
  pin_candidate_if(text, String.starts_with(text, agents_input_prefix()))

def observe_pin(observation: PinObservation, candidate: PinCandidate) -> PinObservation:
  match observation candidate:
    case observation NotPin{}:
      observation
    case observation InvalidPin{}:
      MultiplePins{}
    case NoPin{} ValidPin{revision}:
      OnePin{revision}
    case observation ValidPin{revision}:
      MultiplePins{}

def scan_pins(text: String, observation: PinObservation) -> PinObservation:
  match text:
    case SNil{}:
      observation
    case SCon{+head, +rest}:
      scan_pins(rest, observe_pin(observation, pin_candidate(SCon{head, rest})))

def finish_preparation(revision: String, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.print("Prepared agents-workspace pin " ++ revision ++ ". Review git diff for flake.nix and flake.lock. Publication and NUC deployment require separate approval and the candidate-CI workflow.")
    case OS.ProcessResult{status, out, error}:
      IO.die(Unit, status, "Pin preparation failed. Review local pin changes in flake.nix and flake.lock before retrying; nothing was published or deployed.")

def update_prepared_lock(root: String, revision: String) -> IO(Unit):
  do IO<Unit>:
    Posix.change_directory(root)
    config : String <- Guards.authenticated_nix_config()
    result : OS.ProcessResult <- OS.run_with_environment(["nix", "flake", "update", "agents-workspace"], False{}, "NIX_CONFIG", config)
    finish_preparation(revision, result)

def prepare_pin(+root: String, source: String, +revision: String, observation: PinObservation) -> IO(Unit):
  match observation:
    case OnePin{old}:
      do IO<Unit>:
        updated : String = Text.replace_task_text(source, agents_input_prefix() ++ old, agents_input_prefix() ++ revision)
        Posix.write_text(root ++ "/flake.nix", updated)
        update_prepared_lock(root, revision)
    case observation:
      IO.die(Unit, 1, "Expected exactly one pinned agents-workspace input in flake.nix")

def prepare_files(+root: String, revision: Repository.GitRevision) -> IO(Unit):
  match revision:
    case Repository.GitRevision{value}:
      do IO<Unit>:
        +source : String <- Posix.read_text(root ++ "/flake.nix")
        prepare_pin(root, source, value, scan_pins(source, NoPin{}))

def resolve_workspace(raw: String) -> IO(String):
  match raw:
    case SNil{}:
      do IO<String>:
        home : String <- OS.required_environment("HOME")
        Posix.absolute_path(home ++ "/src/personal/agents-workspace")
    case raw:
      Posix.absolute_path(raw)

def prepare_project(ctx: Context.TaskContext, raw: String) -> IO(Unit):
  match ctx:
    case Context.TaskContext{+root, host, platform}:
      do IO<Unit>:
        +workspace : String <- resolve_workspace(raw)
        Repository.require_clean_repository(workspace, "agents-workspace")
        Repository.require_clean_repository(root, "dotfiles")
        head : String <- OS.output(["git", "-C", workspace, "rev-parse", "HEAD"])
        revision : Repository.GitRevision <- Repository.require_revision(head)
        prepare_files(root, revision)

def execute_prepare_task(task: PrepareTask) -> IO(Unit):
  match task:
    case InvalidPrepareArguments{}:
      IO.die(Unit, 2, "hey: agents:prepare accepts only an optional --workspace path")
    case PrepareWorkspace{raw}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        prepare_project(ctx, raw)
