import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./privilege.bend as Privilege
import ./resources.bend as Resources
import ./system-guards.bend as Guards

type OwnedSudoPane is Data:
  OwnedSudoPane{session: String, block: String}

def scoped_process(argv: List<&2, String>, path: String, config: String, capture: Bool) -> IO(OS.ProcessResult):
  OS.run_with_environment(OS.linear_arguments("/usr/bin/env" <> ("PATH=" ++ path) <> argv), capture, "NIX_CONFIG", config)

def succeeded(result: OS.ProcessResult) -> Bool:
  match result:
    case OS.ProcessResult{0, out, error}:
      True{}
    case result:
      False{}

def prompt_probe(sudo: String, path: String, available: Bool) -> IO(Bool):
  match available:
    case False{}:
      IO.pure(Bool, False{})
    case True{}:
      do IO<Bool>:
        result : OS.ProcessResult <- OS.run(["/usr/bin/env", "PATH=" ++ path, sudo, "-n", "true"], True{})
        return Bool.not(succeeded(result))

def needs_prompt(eligible: Bool, sudo: String, path: String) -> IO(Bool):
  match eligible:
    case False{}:
      IO.pure(Bool, False{})
    case True{}:
      do IO<Bool>:
        available : Bool <- Posix.command_exists("rex")
        prompt_probe(sudo, path, available)

def anchor_arguments(block: String) -> List<&2, String>:
  match block:
    case SNil{}:
      []
    case block:
      ["-b", block]

def print_capture(result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.write(out)
    case OS.ProcessResult{status, out, error}:
      IO.print_err("hey: sudo pane output could not be captured: " ++ error)

def require_absent(pane: OwnedSudoPane, absent: String) -> IO(Unit):
  match pane absent:
    case OwnedSudoPane{session, block} "true":
      IO.pure(Unit, Unit{})
    case OwnedSudoPane{session, block} absent:
      IO.die(Unit, 1, "hey: owned sudo pane did not close: " ++ block)

def verify_absent(pane: OwnedSudoPane) -> IO(Unit):
  match pane:
    case OwnedSudoPane{+session, +block}:
      do IO<Unit>:
        inventory : String <- OS.output(["rex", "block", "ls", "-s", session, "--json"])
        absent : String <- Guards.json_field(inventory, ".blocks | select(type == \"array\") | all(.block_id != " ++ String.quote(block) ++ ") | tostring")
        require_absent(OwnedSudoPane{session, block}, absent)

def handle_owned_pane(+pane: OwnedSudoPane, status: U32, error: String) -> IO(Unit):
  match pane:
    case OwnedSudoPane{+session, +block}:
      do IO<Unit>:
        cleanup : U32 <- Resources.defer_command(["rex", "block", "close", "-s", session, block])
        captured : OS.ProcessResult <- OS.run(["rex", "capture", "-s", session, "-b", block, "--trim"], True{})
        print_capture(captured)
        closed : OS.ProcessResult <- OS.run(["rex", "block", "close", "-s", session, block], True{})
        verify_absent(OwnedSudoPane{session, block})
        Resources.cancel_cleanup(cleanup)
        OS.check(OS.ProcessResult{status, "", error})

def handle_rex_result(session: String, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{status, out, error}:
      do IO<Unit>:
        block : String <- Guards.json_field(out, ".block_ids[0] | select(type == \"string\" and length > 0)")
        handle_owned_pane(OwnedSudoPane{session, block}, status, error)

def run_prompted(sudo: String, args: List<&2, String>, +path: String, +session: String, anchor: String) -> IO(Unit):
  do IO<Unit>:
    IO.print_err("hey: sudo needs a password; enter it in the Rex pane that opens beside this one.")
    prefix : List<&2, String> = List.append(&2, String, ["rex", "split", "-s", session], anchor_arguments(anchor))
    command : List<&2, String> = List.append(&2, String, prefix, List.append(&2, String, ["--wait", "--keep-open", "--json", "--label", "hey: sudo", "--shell", "none", "--", "/usr/bin/env", "PATH=" ++ path, sudo], args))
    result : OS.ProcessResult <- OS.run_with_environment(OS.linear_arguments(command), True{}, "PATH", path)
    handle_rex_result(session, result)

def run_selected(prompt: Bool, sudo: String, args: List<&2, String>, path: String, config: String, session: String, anchor: String) -> IO(Unit):
  match prompt:
    case True{}:
      run_prompted(sudo, args, path, session, anchor)
    case False{}:
      do IO<Unit>:
        result : OS.ProcessResult <- scoped_process(sudo <> args, path, config, False{})
        OS.check(result)

def run_sudo_command(+sudo: String, args: List<&2, String>, +config: String) -> IO(Unit):
  do IO<Unit>:
    current : String <- OS.env("PATH")
    +path : String <- Privilege.privileged_path(["/run/wrappers/bin", "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin"], current)
    enabled : String <- OS.env("HEY_REX")
    +session : String <- OS.env("REX_SESSION")
    anchor : String <- OS.env("REX_BLOCK")
    terminal : Bool <- Posix.stdin_terminal()
    eligible : Bool = Bool.and(Bool.not(String.eq(enabled, "0")), Bool.and(Bool.not(String.is_empty(session)), Bool.not(terminal)))
    prompt : Bool <- needs_prompt(eligible, sudo, path)
    run_selected(prompt, sudo, args, path, config, session, anchor)
