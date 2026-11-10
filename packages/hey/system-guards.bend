import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./resources.bend as Resources
import ./system-policy.bend as Policy
import ./task-text.bend as Text

def json_field(text: String, query: String) -> IO(String):
  do IO<String>:
    +directory : String <- Posix.temporary_directory()
    cleanup : U32 <- Resources.defer_command(["rm", "-rf", "--", directory])
    +path : String = directory ++ "/value.json"
    Posix.write_text(path, text)
    OS.output(["jq", "-er", query, path])

def reject_matches(result: OS.ProcessResult, message: String) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      do IO<Unit>:
        IO.write(out)
        IO.die(Unit, 1, message)
    case OS.ProcessResult{1, out, error}:
      IO.pure(Unit, Unit{})
    case OS.ProcessResult{status, out, error}:
      IO.die(Unit, status, error)

def require_json_lock(result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.pure(Unit, Unit{})
    case result:
      IO.die(Unit, 1, "flake.lock is not valid JSON; check for corruption or conflict markers")

def check_flake_lock(+root: String) -> IO(Unit):
  do IO<Unit>:
    lock_markers : OS.ProcessResult <- OS.run(["grep", "-nE", "^<{7}|^={7}|^>{7}", root ++ "/flake.lock"], True{})
    reject_matches(lock_markers, "flake.lock contains git conflict markers; resolve them first")
    json : OS.ProcessResult <- OS.run(["jq", "empty", root ++ "/flake.lock"], True{})
    require_json_lock(json)
    config_markers : OS.ProcessResult <- OS.run(["git", "-C", root, "grep", "-nE", "^<{7}|^={7}|^>{7}", "--", "*.nix", "*.json", "*.jsonc", "*.yml", "*.yaml", "*.toml"], True{})
    reject_matches(config_markers, "tracked config files contain conflict markers; resolve them first")

def include_leak(name: String, rest: List<&2, String>, leaked: Bool) -> List<&2, String>:
  match leaked:
    case True{}:
      name <> rest
    case False{}:
      rest

def find_skill_leaks(names: List<&2, String>, +local: String, +global: String) -> IO(List<&2, String>):
  match names:
    case Nil{}:
      IO.pure(List<&2, String>, [])
    case +name <> tail:
      do IO<List<&2, String>>:
        local_marker : Bool <- Posix.path_exists(local ++ "/" ++ name ++ "/SKILL.md")
        global_marker : Bool <- Posix.path_exists(global ++ "/" ++ name ++ "/SKILL.md")
        rest : List<&2, String> <- find_skill_leaks(tail, local, global)
        return include_leak(name, rest, Bool.and(local_marker, global_marker))

def local_skill_leaks(root: String, home: String) -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    +local : String = root ++ "/.agents/skills"
    names : List<&2, String> <- Posix.list_directories(local)
    sorted : List<&2, String> = List.sort(~String, ~String.is_le, names)
    find_skill_leaks(sorted, local, home ++ "/.agents/skills")

def print_leaks(names: List<&2, String>) -> IO(Unit):
  match names:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case name <> rest:
      do IO<Unit>:
        IO.print_err("  - " ++ name)
        print_leaks(rest)

def reject_skill_leaks(leaks: List<&2, String>) -> IO(Unit):
  match leaks:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case head <> rest:
      do IO<Unit>:
        IO.print_err("error: dotfiles project-local skills leaked into ~/.agents/skills:")
        print_leaks(head <> rest)
        IO.die(Unit, 1, "Run `hey skills-cleanup-local-leaks`, then retry `hey re`.")

def check_local_skill_leaks(root: String) -> IO(Unit):
  do IO<Unit>:
    home : String <- OS.required_environment("HOME")
    leaks : List<&2, String> <- local_skill_leaks(root, home)
    reject_skill_leaks(leaks)

def append_github_token(existing: String, token: String) -> String:
  match existing token:
    case existing SNil{}:
      existing
    case SNil{} token:
      "access-tokens = github.com=" ++ token
    case existing token:
      Text.concat_task_text([existing, "\naccess-tokens = github.com=", token])

def token_result(existing: String, result: OS.ProcessResult) -> String:
  match result:
    case OS.ProcessResult{0, token, error}:
      append_github_token(existing, String.trim(token))
    case result:
      existing

def authenticated_nix_config() -> IO(String):
  do IO<String>:
    existing : String <- OS.env("NIX_CONFIG")
    token : OS.ProcessResult <- OS.run(["gh", "auth", "token"], True{})
    return token_result(existing, token)

def print_nonempty(text: String, error: Bool) -> IO(Unit):
  match text error:
    case SNil{} error:
      IO.pure(Unit, Unit{})
    case text True{}:
      IO.print_err(text)
    case text False{}:
      IO.print(text)

def archive_status(status: U32, unlocked: Bool) -> IO(Unit):
  match status unlocked:
    case 0 unlocked:
      IO.pure(Unit, Unit{})
    case status True{}:
      IO.print_err("hey re: continuing despite unlocked local input during pre-archive")
    case status False{}:
      IO.die(Unit, status, "nix flake archive failed")

def cache_bootstrap_notice(needed: Bool) -> IO(Unit):
  match needed:
    case True{}:
      IO.print_err("Nix is ignoring this flake's binary cache configuration. Run `hey setup-caches --apply` to trust only the dotfiles-approved caches.")
    case False{}:
      IO.pure(Unit, Unit{})

def check_archive_result(result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{status, out, +error}:
      do IO<Unit>:
        cache_bootstrap_notice(String.contains(error, "--accept-flake-config"))
        print_nonempty(String.trim(out), False{})
        print_nonempty(String.trim(error), True{})
        archive_status(status, String.contains(error, "lock file contains unlocked input"))

def evaluator_line(line: String) -> Bool:
  +text = line
  Bool.or(String.contains(text, "darwinConfigurations"), Bool.or(String.contains(text, "nixosConfigurations"), Bool.or(String.contains(text, "darwin-rebuild"), String.contains(text, "nixos-rebuild"))))

def process_command(text: String) -> String:
  match text:
    case SNil{}:
      ""
    case SCon{Chr{32}, rest}:
      String.trim_start(rest)
    case SCon{Chr{9}, rest}:
      String.trim_start(rest)
    case SCon{head, rest}:
      process_command(rest)

def command_word(text: String, word: String) -> String:
  match text:
    case SNil{}:
      String.reverse(word)
    case SCon{Chr{32}, rest}:
      String.reverse(word)
    case SCon{Chr{9}, rest}:
      String.reverse(word)
    case SCon{head, rest}:
      command_word(rest, SCon{head, word})

def command_basename(text: String, name: String) -> String:
  match text:
    case SNil{}:
      String.reverse(name)
    case SCon{Chr{47}, rest}:
      command_basename(rest, "")
    case SCon{head, rest}:
      command_basename(rest, SCon{head, name})

def noise_command(name: String, args: String) -> Bool:
  match name:
    case "bash":
      String.starts_with(args, "-c ")
    case "sh":
      String.starts_with(args, "-c ")
    case "zsh":
      String.starts_with(args, "-c ")
    case "grep":
      True{}
    case "rg":
      True{}
    case "ps":
      True{}
    case "timeout":
      True{}
    case name:
      False{}

def noise_process(line: String) -> Bool:
  +command = process_command(line)
  name = command_basename(command_word(command, ""), "")
  noise_command(name, process_command(command))

def retain_evaluator(line: String, selected: List<&2, String>, retain: Bool) -> List<&2, String>:
  match retain:
    case True{}:
      String.take(line, 160n) <> selected
    case False{}:
      selected

def select_evaluator(line: String, selected: List<&2, String>, owner: String) -> List<&2, String>:
  +text = String.trim(line)
  retain_evaluator(text, selected, Bool.and(evaluator_line(text), Bool.and(Bool.not(noise_process(text)), Bool.not(String.starts_with(text, owner)))))

def scan_evaluators(text: String, line: String, selected: List<&2, String>, +owner: String) -> List<&2, String>:
  match text:
    case SNil{}:
      List.reverse(&2, String, select_evaluator(String.reverse(line), selected, owner))
    case SCon{Chr{10}, rest}:
      scan_evaluators(rest, "", select_evaluator(String.reverse(line), selected, owner), owner)
    case SCon{head, rest}:
      scan_evaluators(rest, SCon{head, line}, selected, owner)

def evaluator_lines(result: OS.ProcessResult, pid: U32) -> List<&2, String>:
  match result:
    case OS.ProcessResult{0, out, error}:
      scan_evaluators(out, "", [], U32.show(pid) ++ " ")
    case result:
      []

def print_memory_warnings(warnings: List<&2, String>) -> IO(Unit):
  match warnings:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case head <> tail:
      do IO<Unit>:
        IO.print_err("hey re: warning: this machine is under memory pressure; evaluation may be slow:")
        print_leaks(head <> tail)
        IO.print_err("hey re: continuing; stop other Nix evaluations or agent sessions if this drags on.")

def warn_memory_pressure() -> IO(Unit):
  do IO<Unit>:
    memory : Posix.SystemMemory <- Posix.system_memory()
    processes : OS.ProcessResult <- OS.run(["ps", "-axo", "pid=,command="], True{})
    pid : U32 <- Posix.process_id()
    print_memory_warnings(Policy.memory_warnings(memory, evaluator_lines(processes, pid)))
