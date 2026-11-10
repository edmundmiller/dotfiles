import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./resources.bend as Resources
import ./task-context.bend as Context
import ./system-policy.bend as Policy
import ./system-guards.bend as Guards
import ./evaluation-lock.bend as Lock
import ./sudo-prompt.bend as Sudo
import ./privilege.bend as Privilege

type DarwinContext is Data:
  DarwinContext{root: String, host: String, config: String, rebuild: String, sudo: String}

type NixosContext is Data:
  NixosContext{root: String, host: String, config: String, private_github: String}

type RebuildContext is Data:
  DarwinRebuild{context: DarwinContext}
  NixosRebuild{context: NixosContext}

type DarwinSystem is Data:
  DarwinSystem{derivation: String, output: String}

type RebuildIntent is Data:
  GuardedRebuild{}
  TestGeneration{}

type SystemTask is Data:
  RebuildHost{action: String, args: List<&2, String>}
  TestHost{args: List<&2, String>}
  RollbackHost{}

def validate_project(ctx: Context.TaskContext, intent: RebuildIntent) -> IO(Unit):
  match ctx intent:
    case Context.TaskContext{+root, host, platform} GuardedRebuild{}:
      do IO<Unit>:
        Guards.check_flake_lock(root)
        Guards.check_local_skill_leaks(root)
    case ctx TestGeneration{}:
      IO.pure(Unit, Unit{})

def rebuild_context(ctx: Context.TaskContext) -> IO(RebuildContext):
  match ctx:
    case Context.TaskContext{root, host, "Darwin"}:
      do IO<RebuildContext>:
        config : String <- Guards.authenticated_nix_config()
        return DarwinRebuild{DarwinContext{root, host, config, "/run/current-system/sw/bin/darwin-rebuild", "/usr/bin/sudo"}}
    case Context.TaskContext{root, host, "Linux"}:
      do IO<RebuildContext>:
        config : String <- OS.env("NIX_CONFIG")
        return NixosRebuild{NixosContext{root, host, config, "/run/current-system/sw/bin/nix-private-github"}}
    case ctx:
      IO.die(RebuildContext, 1, "hey: system rebuild requires Darwin or Linux")

def selected_rebuild_flags() -> IO(List<&2, String>):
  do IO<List<&2, String>>:
    agent : String <- OS.env("AGENT")
    pi : String <- OS.env("PI_CODING_AGENT")
    claude : String <- OS.env("CLAUDECODE")
    return Policy.rebuild_flags(Policy.agent_mode(agent, pi, claude))

def validate_built_system(derivation: String, output: String, valid: Bool) -> IO(DarwinSystem):
  match valid:
    case True{}:
      IO.pure(DarwinSystem, DarwinSystem{derivation, output})
    case False{}:
      IO.die(DarwinSystem, 1, "nix build returned " ++ output ++ ", which is not a nix-darwin system")

def build_host_system(ctx: DarwinContext, args: List<&2, String>, link: List<&2, String>) -> IO(DarwinSystem):
  match ctx:
    case DarwinContext{root, host, config, rebuild, sudo}:
      do IO<DarwinSystem>:
        IO.print_err("building the system configuration...")
        argv : List<&2, String> = List.append(&2, String, ["nix", "build", "--json"], List.append(&2, String, link, List.append(&2, String, args, [root ++ "#darwinConfigurations." ++ host ++ ".system"])))
        result : OS.ProcessResult <- OS.run_with_environment(OS.linear_arguments(argv), True{}, "NIX_CONFIG", config)
        +json : String <- OS.output_value(result)
        derivation : String <- Guards.json_field(json, ".[0].drvPath | select(type == \"string\" and length > 0)")
        +output : String <- Guards.json_field(json, ".[0].outputs.out | select(type == \"string\" and length > 0)")
        valid : Bool <- Posix.path_exists(output ++ "/activate")
        validate_built_system(derivation, output, valid)

def print_built_system(system: DarwinSystem) -> IO(Unit):
  match system:
    case DarwinSystem{derivation, output}:
      IO.print(output)

def build_only(ctx: DarwinContext, args: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    cwd : String <- Posix.current_directory()
    system : DarwinSystem <- build_host_system(ctx, args, ["--out-link", cwd ++ "/result"])
    print_built_system(system)

def require_resolved(expected: String, actual: String, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "prebuilt flake resolved to " ++ actual ++ ", expected " ++ expected)

def select_rebuild(current: String, built: String, executable: Bool) -> String:
  match executable:
    case True{}:
      current
    case False{}:
      built ++ "/sw/bin/darwin-rebuild"

def resolve_prebuilt(+flake: String, config: String) -> IO(String):
  do IO<String>:
    result : OS.ProcessResult <- OS.run_with_environment(["nix", "build", "--json", "--no-link", "--impure", "--no-write-lock-file", flake ++ "#darwinConfigurations.hey.system"], True{}, "NIX_CONFIG", config)
    json : String <- OS.output_value(result)
    Guards.json_field(json, ".[0].outputs.out | select(type == \"string\" and length > 0)")

def activate_built(ctx: DarwinContext, system: DarwinSystem, +work: String, action: String, flags: List<&2, String>) -> IO(Unit):
  match ctx system:
    case DarwinContext{root, host, +config, +current, sudo} DarwinSystem{derivation, +output}:
      do IO<Unit>:
        +flake : String = work ++ "/flake"
        OS.checked(["mkdir", "-p", flake])
        Posix.write_text(flake ++ "/flake.nix", Policy.render_prebuilt_flake(derivation, output))
        +resolved : String <- resolve_prebuilt(flake, config)
        require_resolved(output, resolved, String.eq(output, resolved))
        executable : Bool <- Posix.path_executable(current)
        command : String = select_rebuild(current, output, executable)
        args : List<&2, String> = command <> List.append(&2, String, ["--flake", flake ++ "#hey"], List.append(&2, String, flags, ["--impure", action]))
        Sudo.run_sudo_command(sudo, args, config)

def prebuilt_activation(+ctx: DarwinContext, action: String, args: List<&2, String>, flags: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    +work : String <- Posix.temporary_directory()
    cleanup : U32 <- Resources.defer_command(["rm", "-rf", "--", work])
    system : DarwinSystem <- build_host_system(ctx, args, ["--out-link", work ++ "/system"])
    activate_built(ctx, system, work, action, flags)
    OS.checked(["rm", "-rf", "--", work])
    Resources.cancel_cleanup(cleanup)

def current_rebuild_command(ctx: DarwinContext) -> String:
  match ctx:
    case DarwinContext{root, host, config, rebuild, sudo}:
      rebuild

def run_upstream(ctx: DarwinContext, action: String, args: List<&2, String>, flags: List<&2, String>, command: String) -> IO(Unit):
  match ctx:
    case DarwinContext{root, host, config, rebuild, sudo}:
      Sudo.run_sudo_command(sudo, command <> List.append(&2, String, ["--flake", root ++ "#" ++ host], List.append(&2, String, flags, action <> args)), config)

def require_fallback(path: String, exists: Bool) -> IO(String):
  match exists:
    case True{}:
      IO.pure(String, path)
    case False{}:
      IO.die(String, 1, "darwin-rebuild fallback missing in build result")

def fallback_command(system: DarwinSystem) -> IO(String):
  match system:
    case DarwinSystem{derivation, output}:
      do IO<String>:
        +path : String = output ++ "/sw/bin/darwin-rebuild"
        exists : Bool <- Posix.path_exists(path)
        require_fallback(path, exists)

def choose_upstream(+ctx: DarwinContext, action: String, args: List<&2, String>, +flags: List<&2, String>, current: String, executable: Bool) -> IO(Unit):
  match executable:
    case True{}:
      run_upstream(ctx, action, args, flags, current)
    case False{}:
      do IO<Unit>:
        system : DarwinSystem <- build_host_system(ctx, flags, ["--no-link"])
        command : String <- fallback_command(system)
        run_upstream(ctx, action, args, flags, command)

def upstream_rebuild(+ctx: DarwinContext, action: String, args: List<&2, String>, flags: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    +current : String = current_rebuild_command(ctx)
    executable : Bool <- Posix.path_executable(current)
    choose_upstream(ctx, action, args, flags, current, executable)

def run_darwin_plan(ctx: DarwinContext, args: List<&2, String>, +flags: List<&2, String>, plan: Policy.DarwinPlan) -> IO(Unit):
  match plan:
    case Policy.UserBuild{}:
      build_only(ctx, List.append(&2, String, flags, args))
    case Policy.PrebuiltSwitch{}:
      prebuilt_activation(ctx, "switch", List.append(&2, String, flags, args), flags)
    case Policy.PrebuiltCheck{}:
      prebuilt_activation(ctx, "check", List.append(&2, String, flags, args), flags)
    case Policy.UpstreamAction{action}:
      upstream_rebuild(ctx, action, args, flags)

def run_darwin(ctx: DarwinContext, action: String, +args: List<&2, String>, flags: List<&2, String>) -> IO(Unit):
  run_darwin_plan(ctx, args, flags, Policy.darwin_plan(action, args))

def nixos_archive(root: String, config: String, private: String, present: Bool) -> IO(OS.ProcessResult):
  match present:
    case True{}:
      OS.run(["sudo", private, "nix", "flake", "archive", "--no-update-lock-file", root], True{})
    case False{}:
      OS.run_with_environment(["nix", "flake", "archive", "--no-update-lock-file", root], True{}, "NIX_CONFIG", config)

def archive_system(ctx: RebuildContext) -> IO(Unit):
  match ctx:
    case DarwinRebuild{DarwinContext{root, host, config, rebuild, sudo}}:
      do IO<Unit>:
        result : OS.ProcessResult <- OS.run_with_environment(["nix", "flake", "archive", "--no-update-lock-file", root], True{}, "NIX_CONFIG", config)
        Guards.check_archive_result(result)
    case NixosRebuild{NixosContext{root, host, config, +private}}:
      do IO<Unit>:
        present : Bool <- Posix.path_exists(private)
        result : OS.ProcessResult <- nixos_archive(root, config, private, present)
        Guards.check_archive_result(result)

def wait_homebrew(ctx: RebuildContext) -> IO(Unit):
  match ctx:
    case DarwinRebuild{DarwinContext{root, host, config, rebuild, sudo}}:
      OS.checked(["bash", root ++ "/bin/hey.d/.lib/wait-homebrew-idle.sh"])
    case NixosRebuild{context}:
      IO.pure(Unit, Unit{})

def run_nixos(ctx: NixosContext, action: String, args: List<&2, String>, flags: List<&2, String>, present: Bool) -> IO(Unit):
  match ctx present:
    case NixosContext{root, host, config, private} True{}:
      Privilege.run_privileged(OS.linear_arguments(List.append(&2, String, ["sudo", private, "nixos-rebuild", "--flake", root], List.append(&2, String, flags, action <> args))))
    case NixosContext{root, host, config, private} False{}:
      Privilege.run_privileged(OS.linear_arguments(List.append(&2, String, ["nixos-rebuild", "--flake", root, "--sudo"], List.append(&2, String, flags, action <> args))))

def match_nixos_presence(ctx: NixosContext, action: String, args: List<&2, String>, flags: List<&2, String>) -> IO(Unit):
  match ctx:
    case NixosContext{+root, +host, +config, +private}:
      do IO<Unit>:
        present : Bool <- Posix.path_exists(private)
        run_nixos(NixosContext{root, host, config, private}, action, args, flags, present)

def run_platform(ctx: RebuildContext, action: String, args: List<&2, String>, flags: List<&2, String>) -> IO(Unit):
  match ctx:
    case DarwinRebuild{context}:
      run_darwin(context, action, args, flags)
    case NixosRebuild{+context}:
      match_nixos_presence(context, action, args, flags)

def evaluation_label(ctx: RebuildContext, action: String) -> String:
  match ctx:
    case DarwinRebuild{DarwinContext{root, host, config, rebuild, sudo}}:
      "hey " ++ action ++ " " ++ host
    case NixosRebuild{NixosContext{root, host, config, private}}:
      "hey " ++ action ++ " " ++ host

def system_rebuild(+ctx: RebuildContext, +action: String, args: List<&2, String>, flags: List<&2, String>) -> IO(Unit):
  do IO<Unit>:
    archive_system(ctx)
    wait_homebrew(ctx)
    lease : Lock.EvaluationLease <- Lock.acquire_evaluation_lock(evaluation_label(ctx, action))
    Guards.warn_memory_pressure()
    run_platform(ctx, action, args, flags)
    Lock.release_evaluation_lock(lease)

def post_linux(result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.print("=== hermes-agent: system-managed restart handled by activation ===")
    case result:
      IO.print("=== no Hermes system service present ===")

def post_rebuild(ctx: RebuildContext, intent: RebuildIntent) -> IO(Unit):
  match ctx intent:
    case ctx TestGeneration{}:
      IO.pure(Unit, Unit{})
    case DarwinRebuild{context} GuardedRebuild{}:
      IO.pure(Unit, Unit{})
    case NixosRebuild{context} GuardedRebuild{}:
      do IO<Unit>:
        result : OS.ProcessResult <- OS.run(["systemctl", "list-unit-files", "hermes-agent.service"], True{})
        post_linux(result)

def rollback_context(ctx: Context.TaskContext) -> IO(Unit):
  match ctx:
    case Context.TaskContext{root, host, "Darwin"}:
      do IO<Unit>:
        config : String <- OS.env("NIX_CONFIG")
        Sudo.run_sudo_command("/usr/bin/sudo", ["/run/current-system/sw/bin/darwin-rebuild", "--rollback"], config)
    case Context.TaskContext{root, host, "Linux"}:
      Privilege.run_privileged(["nixos-rebuild", "--sudo", "--rollback", "switch"])
    case ctx:
      IO.die(Unit, 1, "hey: rollback requires Darwin or Linux")

def execute_rebuild_request(action: String, args: List<&2, String>, +intent: RebuildIntent) -> IO(Unit):
  do IO<Unit>:
    +project : Context.TaskContext <- Context.task_context()
    validate_project(project, intent)
    +context : RebuildContext <- rebuild_context(project)
    flags : List<&2, String> <- selected_rebuild_flags()
    system_rebuild(context, action, args, flags)
    post_rebuild(context, intent)

def execute_system_task(task: SystemTask) -> IO(Unit):
  match task:
    case RebuildHost{action, args}:
      execute_rebuild_request(action, args, GuardedRebuild{})
    case TestHost{args}:
      execute_rebuild_request("test", args, TestGeneration{})
    case RollbackHost{}:
      do IO<Unit>:
        project : Context.TaskContext <- Context.task_context()
        rollback_context(project)
