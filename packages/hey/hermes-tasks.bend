import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-context.bend as Context
import ./task-text.bend as Text
import ./gateway-status.bend as Gateway

type HermesMode is Data:
  RebuildHermes{}
  CheckHermes{}
  InvalidHermesArguments{}

type ProfileLauncher is Data:
  ProfileLauncher{name: String, expected: String}

type HermesManifest is Data:
  HermesManifest{revision: String, hermes: String, profiles: List<&2, ProfileLauncher>}

def task_request(name: String, args: List<&2, String>) -> HermesMode:
  match name args:
    case "hermes:local" Nil{}:
      RebuildHermes{}
    case "hermes:local" "--smoke-only" <> Nil{}:
      CheckHermes{}
    case name args:
      InvalidHermesArguments{}

def require_success(label: String, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.pure(Unit, Unit{})
    case OS.ProcessResult{+status, out, error}:
      IO.die(Unit, status, label ++ " failed with exit status " ++ U32.show(status))

def require_text_result(label: String, expected: String, present: Bool) -> IO(Unit):
  match present:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, label ++ " missing expected text: " ++ expected)

def require_text(label: String, text: String, +expected: String) -> IO(Unit):
  require_text_result(label, expected, String.contains(text, expected))

def prepend_profile(name: String, expected: String, rest: Maybe<&2, List<&2, ProfileLauncher>>) -> Maybe<&2, List<&2, ProfileLauncher>>:
  match rest:
    case Some{profiles}:
      Some{ProfileLauncher{name, expected} <> profiles}
    case None{}:
      None{}

def manifest_profiles(fields: List<&2, String>) -> Maybe<&2, List<&2, ProfileLauncher>>:
  match fields:
    case Nil{}:
      Some{[]}
    case name <> expected <> rest:
      prepend_profile(name, expected, manifest_profiles(rest))
    case fields:
      None{}

def parsed_manifest(revision: String, hermes: String, profiles: Maybe<&2, List<&2, ProfileLauncher>>) -> IO(HermesManifest):
  match profiles:
    case Some{launchers}:
      IO.pure(HermesManifest, HermesManifest{revision, hermes, launchers})
    case None{}:
      IO.die(HermesManifest, 1, "Invalid Hermes apply manifest profile entries")

def manifest_fields(fields: List<&2, String>) -> IO(HermesManifest):
  match fields:
    case revision <> hermes <> rest:
      parsed_manifest(revision, hermes, manifest_profiles(rest))
    case fields:
      IO.die(HermesManifest, 1, "Invalid Hermes apply manifest fields")

def manifest_result(result: OS.ProcessResult) -> IO(HermesManifest):
  match result:
    case OS.ProcessResult{0, out, error}:
      manifest_fields(Text.nul_separated_paths(out))
    case result:
      IO.die(HermesManifest, 1, "Invalid or missing Hermes apply manifest; rebuild Hermes host wiring first")

def read_manifest(home: String) -> IO(HermesManifest):
  do IO<HermesManifest>:
    result : OS.ProcessResult <- OS.run(["jq", "-jer", ". as $m | select(type == \"object\" and (.agentsWorkspaceRevision | type == \"string\" and length > 0 and index(\"\\u0000\") == null) and (.hermes | type == \"string\" and startswith(\"/\") and index(\"\\u0000\") == null) and (.profiles | type == \"array\" and all(.[]; type == \"string\" and test(\"^[A-Za-z0-9][A-Za-z0-9_-]*$\"))) and (.launchers | type == \"object\") and ($m.profiles | all(.[]; . as $p | $m.launchers[$p] | type == \"string\" and startswith(\"/\") and index(\"\\u0000\") == null))) | .agentsWorkspaceRevision, \"\\u0000\", .hermes, \"\\u0000\", (.profiles[] as $p | $p, \"\\u0000\", .launchers[$p], \"\\u0000\")", home ++ "/.config/hermes-local/manifest.json"], True{})
    manifest_result(result)

def require_command(name: String, result: Maybe<&2, String>) -> IO(String):
  match result:
    case Some{path}:
      Posix.absolute_path(path)
    case None{}:
      IO.die(String, 1, "Hermes runtime command missing: " ++ name)

def resolved_command(+name: String) -> IO(String):
  do IO<String>:
    found : Maybe<&2, String> <- Posix.find_command(name)
    require_command(name, found)

def require_runtime_path(name: String, actual: String, expected: String, matches: Bool) -> IO(Unit):
  match matches:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, name ++ " binary drift: active=" ++ actual ++ " expected=" ++ expected)

def verify_runtime_path(+name: String, +expected: String) -> IO(Unit):
  do IO<Unit>:
    +actual : String <- resolved_command(name)
    require_runtime_path(name, actual, expected, String.eq(actual, expected))

def check_profiles(profiles: List<&2, ProfileLauncher>, +home: String, +revision: String) -> IO(Unit):
  match profiles:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case ProfileLauncher{+name, expected} <> rest:
      do IO<Unit>:
        +launcher : String = name ++ "-hermes"
        verify_runtime_path(launcher, expected)
        rendered : OS.ProcessResult <- OS.run([launcher, "config", "check"], True{})
        require_success("render and validate " ++ name, rendered)
        Posix.write_text(home ++ "/.hermes/profiles/" ++ name ++ "/.agents-workspace-revision", revision)
        check_profiles(rest, home, revision)

def require_inventory(profiles: List<&2, ProfileLauncher>, +inventory: String) -> IO(Unit):
  match profiles:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case ProfileLauncher{name, expected} <> rest:
      do IO<Unit>:
        require_text("Hermes profile inventory", inventory, name)
        require_inventory(rest, inventory)

type GatewayObservation is Data:
  GatewayHealthy{}
  GatewayPending{}

def gateway_pid_observation(pid: Maybe<&2, U32>) -> GatewayObservation:
  match pid:
    case Some{value}:
      GatewayHealthy{}
    case None{}:
      GatewayPending{}

def gateway_observation(result: OS.ProcessResult) -> GatewayObservation:
  match result:
    case OS.ProcessResult{0, out, error}:
      gateway_pid_observation(Gateway.gateway_pid(out))
    case result:
      GatewayPending{}

def wait_gateway(fuel: Nat, observation: GatewayObservation) -> IO(Unit):
  match fuel observation:
    case fuel GatewayHealthy{}:
      IO.pure(Unit, Unit{})
    case 0n GatewayPending{}:
      IO.die(Unit, 1, "Orchestrator gateway status missing a running PID after 10 seconds")
    case 1n+rest GatewayPending{}:
      do IO<Unit>:
        OS.checked(["sleep", "1"])
        result : OS.ProcessResult <- OS.run(["orchestrator-hermes", "gateway", "status"], True{})
        wait_gateway(rest, gateway_observation(result))

def start_gateway() -> IO(Unit):
  do IO<Unit>:
    install : OS.ProcessResult <- OS.run(["orchestrator-hermes", "gateway", "install"], True{})
    require_success("Orchestrator gateway install", install)
    start : OS.ProcessResult <- OS.run(["orchestrator-hermes", "gateway", "start"], True{})
    require_success("Orchestrator gateway start", start)
    status : OS.ProcessResult <- OS.run(["orchestrator-hermes", "gateway", "status"], True{})
    wait_gateway(10n, gateway_observation(status))

def profile_names(profiles: List<&2, ProfileLauncher>) -> List<&2, String>:
  match profiles:
    case Nil{}:
      []
    case ProfileLauncher{name, expected} <> rest:
      name <> profile_names(rest)

def check_inventory(profiles: List<&2, ProfileLauncher>, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{status, out, error}:
      require_inventory(profiles, out)

def require_chatgpt_login(result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{status, out, error}:
      require_text("Codex login", Text.concat_task_text([out, "\n", error]), "Logged in using ChatGPT")

def check_codex_login(+result: OS.ProcessResult) -> IO(Unit):
  do IO<Unit>:
    require_success("Codex login", result)
    require_chatgpt_login(result)

def check_local_hermes(+home: String, manifest: HermesManifest) -> IO(Unit):
  match manifest:
    case HermesManifest{+revision, +hermes, +profiles}:
      do IO<Unit>:
        verify_runtime_path("hermes", hermes)
        check_profiles(profiles, home, revision)
        +inventory : OS.ProcessResult <- OS.run(["hermes", "profile", "list"], True{})
        require_success("Hermes profile inventory", inventory)
        check_inventory(profiles, inventory)
        login : OS.ProcessResult <- OS.run(["codex", "login", "status"], True{})
        check_codex_login(login)
        start_gateway()
        dispatcher : OS.ProcessResult <- OS.run(["orchestrator-hermes", "kanban", "dispatch", "--dry-run", "--json"], True{})
        require_success("Kanban dispatcher", dispatcher)
        IO.print(Text.concat_task_text(["PASS hermes-local\n  binary: ", hermes, "\n  agents-workspace: ", revision, "\n  profiles: ", String.join(profile_names(profiles), ", "), "\n  Codex: ChatGPT login active\n  gateway: running\n  Kanban dispatcher: healthy"]))

def rebuild_project(ctx: Context.TaskContext) -> IO(Unit):
  match ctx:
    case Context.TaskContext{root, host, platform}:
      OS.checked(["mise", "--cd", root, "run", "rebuild"])

def maybe_rebuild(mode: HermesMode) -> IO(Unit):
  match mode:
    case RebuildHermes{}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        rebuild_project(ctx)
    case mode:
      IO.pure(Unit, Unit{})

def run_hermes_mode(mode: HermesMode, platform: String) -> IO(Unit):
  match platform:
    case "Darwin":
      do IO<Unit>:
        maybe_rebuild(mode)
        +home : String <- OS.required_environment("HOME")
        manifest : HermesManifest <- read_manifest(home)
        check_local_hermes(home, manifest)
    case platform:
      IO.die(Unit, 1, "hey hermes-local is Darwin-only")

def execute_hermes_task(mode: HermesMode) -> IO(Unit):
  match mode:
    case InvalidHermesArguments{}:
      IO.die(Unit, 2, "hey: invalid Hermes arguments; use --help for usage")
    case mode:
      do IO<Unit>:
        platform : String <- Posix.platform_name()
        run_hermes_mode(mode, platform)
