import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-context.bend as Context
import ./host-tasks.bend as Host
import ./remote-arguments.bend as Remote
import ./system-rebuild.bend as System

type TaskRequest is Data:
  ExternalCommand{argv: List<&2, String>}
  CommandSequence{commands: List<&2, List<&2, String>>}
  ProjectCommands{commands: List<&2, List<&2, String>>}
  ProjectScript{prefix: List<&2, String>, path: String, args: List<&2, String>}
  UpdateInputs{inputs: List<&2, String>}
  UpdateSkills{after: List<&2, List<&2, String>>}
  UpdatePi{version: String}
  BenchmarkFile{directory: String, extension: String, missing: String}
  HostOperation{task: Host.HostTask}
  SystemOperation{task: System.SystemTask}
  InvalidArguments{}

def nuc_logs_request(unit: String, count: Maybe<&2, U32>) -> TaskRequest:
  match count:
    case Some{lines}:
      ExternalCommand{["ssh", "nuc", Remote.journal_command(unit, lines)]}
    case None{}:
      InvalidArguments{}

def task_request(name: String, args: List<&2, String>) -> TaskRequest:
  match name args:
    case "rebuild" Nil{}:
      SystemOperation{System.RebuildHost{"switch", []}}
    case "rebuild" Con{action, args}:
      SystemOperation{System.RebuildHost{action, args}}
    case "test" args:
      SystemOperation{System.TestHost{args}}
    case "rollback" Nil{}:
      SystemOperation{System.RollbackHost{}}
    case "agent:adopt" args:
      ExternalCommand{"agent-run" <> "adopt" <> args}
    case "agent:checkpoint" args:
      ExternalCommand{"agent-run" <> "checkpoint" <> args}
    case "agent:complete" args:
      ExternalCommand{"agent-run" <> "complete" <> args}
    case "agent:start" args:
      ExternalCommand{"agent-run" <> "start" <> args}
    case "agent:sweep" args:
      ExternalCommand{"agent-run" <> "sweep" <> args}
    case "search" Con{query, Nil{}}:
      ExternalCommand{["nix", "search", "nixpkgs", query]}
    case "shell" Con{package, Nil{}}:
      ExternalCommand{["nix", "shell", "nixpkgs#" ++ package]}
    case "show" Nil{}:
      ProjectCommands{[["nix", "flake", "show"]]}
    case "update" inputs:
      UpdateInputs{inputs}
    case "upgrade" Nil{}:
      CommandSequence{[["mise", "run", "update"], ["mise", "run", "rebuild"]]}
    case "skills:update" Nil{}:
      UpdateSkills{[]}
    case "skills:sync" Nil{}:
      ProjectCommands{[["nix", "flake", "update", "skills-catalog"], ["mise", "run", "rebuild"]]}
    case "skills:bump" Nil{}:
      UpdateSkills{[["nix", "flake", "update", "skills-catalog"], ["mise", "run", "rebuild"]]}
    case "pi:update" Con{version, Nil{}}:
      UpdatePi{version}
    case "qa-changed" args:
      ProjectScript{[], "bin/qa-changed", args}
    case "reclaim-mac-development" args:
      ProjectScript{["python3"], "scripts/reclaim-mac-development.py", args}
    case "unas:recover" Con{root, Con{system, Nil{}}}:
      ProjectScript{["bash"], "bin/unas-recover", [root, system]}
    case "deploy" Con{host, Nil{}}:
      HostOperation{Host.DeployHost{host, False{}}}
    case "deploy:dry" Con{"nuc", Nil{}}:
      ExternalCommand{["mise", "run", "nuc", "--", "dry-activate"]}
    case "deploy:dry" Con{host, Nil{}}:
      HostOperation{Host.DeployHost{host, True{}}}
    case "unas" Nil{}:
      HostOperation{Host.DeployUnas{False{}}}
    case "unas" Con{"remote", Nil{}}:
      HostOperation{Host.DeployUnas{False{}}}
    case "unas" Con{"local", Nil{}}:
      HostOperation{Host.DeployUnas{True{}}}
    case "gc" Nil{}:
      HostOperation{Host.GarbageCollection{False{}}}
    case "gc" Con{"--keep-generations", Nil{}}:
      HostOperation{Host.GarbageCollection{True{}}}
    case "mole:upgrade" Nil{}:
      HostOperation{Host.UpgradeMole{}}
    case "opencode:update" Nil{}:
      HostOperation{Host.CleanOpenCode{}}
    case "nuc:service" Con{service, Nil{}}:
      ExternalCommand{["ssh", "nuc", Remote.service_status_command(service)]}
    case "nuc:logs" Nil{}:
      nuc_logs_request("", Some{50})
    case "nuc:logs" Con{unit, Nil{}}:
      nuc_logs_request(unit, Some{50})
    case "nuc:logs" Con{unit, Con{count, Nil{}}}:
      nuc_logs_request(unit, U32.read(count))
    case "nuc:status" Nil{}:
      ExternalCommand{["ssh", "nuc", "echo \"Hostname: $(hostname)\"; echo \"Uptime: $(uptime)\"; echo; echo 'Current Generation:'; sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1"]}
    case "deploy:check" Nil{}:
      ExternalCommand{["mise", "run", "nuc", "--", "dry-activate"]}
    case "ergodox:build-flash" Nil{}:
      CommandSequence{[["mise", "run", "ergodox:build"], ["mise", "run", "ergodox:flash"]]}
    case "nuc:rebuild" Nil{}:
      ExternalCommand{["mise", "run", "nuc"]}
    case "nuc:test" Nil{}:
      ExternalCommand{["mise", "run", "nuc", "--", "dry-activate"]}
    case "nuc:ssh" Nil{}:
      ExternalCommand{["ssh", "-t", "nuc"]}
    case "unas:ssh" Nil{}:
      ExternalCommand{["ssh", "-t", "192.168.1.206"]}
    case "nuc:generations" Nil{}:
      ExternalCommand{["ssh", "nuc", "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system"]}
    case "nuc:rollback" Nil{}:
      ExternalCommand{["ssh", "-t", "nuc", "sudo nix-private-github nixos-rebuild --rollback switch"]}
    case "zbench:baseline" Nil{}:
      BenchmarkFile{"", ".json", "No baseline saved. Run: hey zbench-save"}
    case "zbench:history" Nil{}:
      BenchmarkFile{"history/", ".tsv", "No history. Run: hey zbench-save"}
    case name args:
      InvalidArguments{}

def run_commands(commands: List<&2, List<&2, String>>) -> IO(Unit):
  match commands:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{argv, rest}:
      do IO<Unit>:
        OS.checked(OS.linear_arguments(argv))
        run_commands(rest)

def run_project_commands(ctx: Context.TaskContext, commands: List<&2, List<&2, String>>) -> IO(Unit):
  match ctx:
    case Context.TaskContext{root, host, platform}:
      do IO<Unit>:
        Posix.change_directory(root)
        run_commands(commands)

def run_project_script(ctx: Context.TaskContext, prefix: List<&2, String>, path: String, args: List<&2, String>) -> IO(Unit):
  match ctx:
    case Context.TaskContext{root, host, platform}:
      OS.checked(OS.linear_arguments(List.append(&2, String, prefix, (root ++ "/" ++ path) <> args)))

def update_remaining_inputs(inputs: List<&2, String>) -> IO(Unit):
  match inputs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{input, rest}:
      do IO<Unit>:
        OS.checked(["nix", "flake", "update", input])
        update_remaining_inputs(rest)

def update_inputs(inputs: List<&2, String>) -> IO(Unit):
  match inputs:
    case Nil{}:
      OS.checked(["nix", "flake", "update"])
    case Con{input, rest}:
      do IO<Unit>:
        OS.checked(["nix", "flake", "update", input])
        update_remaining_inputs(rest)

def update_project_inputs(ctx: Context.TaskContext, inputs: List<&2, String>) -> IO(Unit):
  match ctx:
    case Context.TaskContext{root, host, platform}:
      do IO<Unit>:
        Posix.change_directory(root)
        update_inputs(inputs)

def update_skills_inputs(ctx: Context.TaskContext, after: List<&2, List<&2, String>>) -> IO(Unit):
  match ctx:
    case Context.TaskContext{+root, host, platform}:
      do IO<Unit>:
        Posix.change_directory(root ++ "/skills")
        OS.checked(["nix", "flake", "update"])
        Posix.change_directory(root)
        run_commands(after)

def update_pi(ctx: Context.TaskContext, version: String) -> IO(Unit):
  match ctx:
    case Context.TaskContext{+root, host, platform}:
      do IO<Unit>:
        OS.checked(["nix", "run", root ++ "#pi.updater", "--", root ++ "/overlays/pi", version])
        OS.checked(["mise", "--cd", root, "run", "rebuild"])

def show_benchmark_file(+path: String, missing: String, exists: Bool) -> IO(Unit):
  match exists:
    case True{}:
      do IO<Unit>:
        content : String <- Posix.read_text(path)
        IO.write(content)
    case False{}:
      IO.print(missing)

def benchmark_file(ctx: Context.TaskContext, directory: String, extension: String, missing: String) -> IO(Unit):
  match ctx:
    case Context.TaskContext{root, host, platform}:
      do IO<Unit>:
        +path : String = root ++ "/benchmarks/zsh-bench/" ++ directory ++ host ++ extension
        exists : Bool <- Posix.path_exists(path)
        show_benchmark_file(path, missing, exists)

def execute_request(request: TaskRequest) -> IO(Unit):
  match request:
    case ExternalCommand{argv}:
      OS.checked(OS.linear_arguments(argv))
    case CommandSequence{commands}:
      run_commands(commands)
    case ProjectCommands{commands}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        run_project_commands(ctx, commands)
    case ProjectScript{prefix, path, args}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        run_project_script(ctx, prefix, path, args)
    case UpdateInputs{inputs}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        update_project_inputs(ctx, inputs)
    case UpdatePi{version}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        update_pi(ctx, version)
    case UpdateSkills{after}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        update_skills_inputs(ctx, after)
    case BenchmarkFile{directory, extension, missing}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        benchmark_file(ctx, directory, extension, missing)
    case HostOperation{task}:
      Host.execute_host_task(task)
    case SystemOperation{task}:
      System.execute_system_task(task)
    case InvalidArguments{}:
      IO.die(Unit, 2, "hey: invalid task arguments; use --help for usage")
