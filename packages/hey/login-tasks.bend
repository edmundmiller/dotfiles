import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./privilege.bend as Privilege
import ./remote-arguments.bend as Remote
import ./task-text.bend as Text

type LoginTask is Data:
  LoginBetty{}
  LoginScintillate{}

type LoginRequest is Data:
  StartLogin{target: LoginTask}
  InvalidLoginArguments{}

type LoginLocation is Data:
  LocalNuc{}
  RemoteNuc{}

type CommandAuthority is Data:
  UserCommand{}
  PrivilegedCommand{}

type TerminalMode is Data:
  InteractiveTerminal{}
  OrdinaryStreams{}

def task_request(name: String, args: List<&2, String>) -> LoginRequest:
  match name args:
    case "login:betty" Nil{}:
      StartLogin{LoginBetty{}}
    case "login:scintillate" Nil{}:
      StartLogin{LoginScintillate{}}
    case name args:
      InvalidLoginArguments{}

def login_location(hostname: String) -> LoginLocation:
  match hostname:
    case "nuc":
      LocalNuc{}
    case hostname:
      RemoteNuc{}

def quoted_command(args: List<&2, String>) -> String:
  match args:
    case Nil{}:
      ""
    case head <> Nil{}:
      Remote.quote_argument(head)
    case head <> rest:
      Text.concat_task_text([Remote.quote_argument(head), " ", quoted_command(rest)])

def remote_privileged_prefix() -> String:
  "PATH=" ++ Remote.quote_argument("/run/wrappers/bin") ++ ":$PATH "

def remote_command(authority: CommandAuthority, args: List<&2, String>) -> String:
  match authority:
    case UserCommand{}:
      quoted_command(args)
    case PrivilegedCommand{}:
      remote_privileged_prefix() ++ quoted_command("sudo" <> args)

def remote_login_command(terminal: TerminalMode, command: String) -> IO(Unit):
  match terminal:
    case InteractiveTerminal{}:
      OS.checked(["ssh", "-t", "nuc", command])
    case OrdinaryStreams{}:
      OS.checked(["ssh", "nuc", command])

def execute_login_command(location: LoginLocation, authority: CommandAuthority, terminal: TerminalMode, args: List<&2, String>) -> IO(Unit):
  match location authority:
    case LocalNuc{} UserCommand{}:
      OS.checked(OS.linear_arguments(args))
    case LocalNuc{} PrivilegedCommand{}:
      Privilege.run_privileged(OS.linear_arguments("sudo" <> args))
    case RemoteNuc{} authority:
      remote_login_command(terminal, remote_command(authority, args))

def run_auth_paths(location: LoginLocation, command: String) -> IO(Unit):
  match location:
    case LocalNuc{}:
      Privilege.run_privileged(["bash", "-c", command])
    case RemoteNuc{}:
      remote_login_command(OrdinaryStreams{}, remote_privileged_prefix() ++ quoted_command(["bash", "-c", command]))

def print_betty_auth_paths(location: LoginLocation) -> IO(Unit):
  do IO<Unit>:
    IO.print("\n=== Auth paths ===")
    command : String = Text.concat_task_text(["set -euo pipefail; ", quoted_command(["sudo", "find", "/var/lib/hermes-betty", "-maxdepth", "3", "(", "-path", "*/.codex*", "-o", "-name", "auth.json*", ")", "-printf", "%M %u:%g %p -> %l\n"]), " | sort"])
    run_auth_paths(location, command)

def login_betty(+location: LoginLocation) -> IO(Unit):
  do IO<Unit>:
    IO.print("=== Betty Codex login ===\nThis stores Codex OAuth in Betty-owned state:\n  /var/lib/hermes-betty/.codex\n  /var/lib/hermes-betty/.hermes/auth.json\nIt does not copy or reuse /home/emiller/.codex/auth.json.\n\nFollow the printed OpenAI device-login URL and enter the one-time code.\nIf OpenAI says the session is invalid, press Ctrl+C here and rerun hey login-betty;\nthen open the new URL/code in a private/incognito browser window.\n")
    execute_login_command(location, PrivilegedCommand{}, InteractiveTerminal{}, ["docker", "exec", "-it", "hermes-agent-betty", "bash", "-lc", "hermes auth add openai-codex --type oauth"])
    IO.print("\n=== Verifying Betty openai-codex invocation ===")
    execute_login_command(location, PrivilegedCommand{}, OrdinaryStreams{}, ["docker", "exec", "hermes-agent-betty", "bash", "-lc", "hermes auth status openai-codex && timeout 180 hermes --provider openai-codex -m gpt-5.6-luna -z \"Reply with exactly: OK\""])
    IO.print("\n=== Verifying Scintillate still has independent Codex auth ===")
    execute_login_command(location, PrivilegedCommand{}, OrdinaryStreams{}, ["docker", "exec", "hermes-agent-scintillate", "bash", "-lc", "timeout 180 hermes --provider openai-codex -m gpt-5.5 -z \"Reply with exactly: OK\""])
    print_betty_auth_paths(location)

def login_scintillate(+location: LoginLocation) -> IO(Unit):
  do IO<Unit>:
    IO.print("=== Scintillate Codex login ===\nThis stores Codex OAuth in /var/lib/hermes-scintillate/.hermes/auth.json.\nIt does not copy or reuse ~/.codex/auth.json.\n")
    execute_login_command(location, UserCommand{}, InteractiveTerminal{}, ["docker", "exec", "-it", "hermes-agent-scintillate", "hermes", "auth", "add", "openai-codex", "--no-browser"])
    IO.print("\n=== Verifying direct openai-codex invocation ===")
    execute_login_command(location, UserCommand{}, OrdinaryStreams{}, ["docker", "exec", "hermes-agent-scintillate", "bash", "-lc", "timeout 180 hermes --provider openai-codex -m gpt-5.5 -z \"Reply with exactly: OK\""])

def run_login_task(task: LoginTask, hostname: String) -> IO(Unit):
  match task:
    case LoginBetty{}:
      login_betty(login_location(hostname))
    case LoginScintillate{}:
      login_scintillate(login_location(hostname))

def execute_login_task(task: LoginRequest) -> IO(Unit):
  match task:
    case InvalidLoginArguments{}:
      IO.die(Unit, 2, "hey: invalid login arguments; use --help for usage")
    case StartLogin{target}:
      do IO<Unit>:
        hostname : String <- Posix.host_name()
        run_login_task(target, hostname)
