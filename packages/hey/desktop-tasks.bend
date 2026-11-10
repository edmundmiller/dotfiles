import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-context.bend as Context
import ./task-text.bend as Text
import ./resources.bend as Resources
import ./system-guards.bend as Guards
import ./system-policy.bend as Policy

type BenchmarkMode is Data:
  RunBenchmark{}
  CheckBenchmark{}
  CompareBenchmark{}
  SaveBenchmark{}

type CacheMode is Data:
  PreviewCaches{}
  ApplyCaches{}

type ContextDesktopTask is Data:
  BuildFirmware{}
  EditFirmware{}
  FlashFirmware{hex: String}
  DrawFirmware{}
  FirmwareInfo{}
  NixRepl{}
  SynchronizeSkillkit{}
  CleanSkillLeaks{}
  TestZsh{args: List<&2, String>}
  BenchmarkZsh{mode: BenchmarkMode, args: List<&2, String>}

type DesktopTask is Data:
  ContextOperation{task: ContextDesktopTask}
  ConfigureCaches{mode: CacheMode}
  InvalidDesktopArguments{}

def task_request(name: String, args: List<&2, String>) -> DesktopTask:
  match name args:
    case "ergodox:build" Nil{}:
      ContextOperation{BuildFirmware{}}
    case "ergodox:edit" Nil{}:
      ContextOperation{EditFirmware{}}
    case "ergodox:flash" Nil{}:
      ContextOperation{FlashFirmware{""}}
    case "ergodox:flash" hex <> Nil{}:
      ContextOperation{FlashFirmware{hex}}
    case "ergodox:draw" Nil{}:
      ContextOperation{DrawFirmware{}}
    case "ergodox:info" Nil{}:
      ContextOperation{FirmwareInfo{}}
    case "repl" Nil{}:
      ContextOperation{NixRepl{}}
    case "skillkit:sync" Nil{}:
      ContextOperation{SynchronizeSkillkit{}}
    case "skills:cleanup-local-leaks" Nil{}:
      ContextOperation{CleanSkillLeaks{}}
    case "ztest" args:
      ContextOperation{TestZsh{args}}
    case "zbench" args:
      ContextOperation{BenchmarkZsh{RunBenchmark{}, args}}
    case "zbench:check" args:
      ContextOperation{BenchmarkZsh{CheckBenchmark{}, args}}
    case "zbench:compare" args:
      ContextOperation{BenchmarkZsh{CompareBenchmark{}, args}}
    case "zbench:save" args:
      ContextOperation{BenchmarkZsh{SaveBenchmark{}, args}}
    case "setup-caches" Nil{}:
      ConfigureCaches{PreviewCaches{}}
    case "setup-caches" "--apply" <> Nil{}:
      ConfigureCaches{ApplyCaches{}}
    case name args:
      InvalidDesktopArguments{}

def select_file(include: Bool, name: String, selected: List<&2, String>) -> List<&2, String>:
  match include:
    case True{}:
      name <> selected
    case False{}:
      selected

def suffix_files(files: List<&2, String>, +suffix: String, selected: List<&2, String>) -> List<&2, String>:
  match files:
    case Nil{}:
      List.reverse(&2, String, selected)
    case +name <> rest:
      suffix_files(rest, suffix, select_file(String.ends_with(name, suffix), name, selected))

def copy_firmware(files: List<&2, String>, +destination: String) -> IO(Unit):
  match files:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case name <> rest:
      do IO<Unit>:
        OS.checked(["cp", "-f", "result/" ++ name, destination ++ "/"])
        copy_firmware(rest, destination)

def finish_firmware_build(hex: List<&2, String>, checksums: List<&2, String>, +destination: String) -> IO(Unit):
  match hex checksums:
    case Nil{} checksums:
      IO.die(Unit, 1, "hey: firmware build produced no .hex files")
    case hex Nil{}:
      IO.die(Unit, 1, "hey: firmware build produced no .md5 files")
    case +first <> +rest checksums:
      do IO<Unit>:
        copy_firmware(first <> rest, destination)
        copy_firmware(checksums, destination)
        IO.print("\nBuild complete!\nFirmware: " ++ destination ++ "/" ++ first ++ "\n\nFlash with: hey ergodox-flash")

def build_firmware(+root: String) -> IO(Unit):
  do IO<Unit>:
    IO.print("Building ErgoDox firmware with nix...\nSource: " ++ root ++ "/packages/ergodox-firmware/src\n")
    Posix.change_directory(root)
    OS.checked(["nix", "build", ".#ergodox-firmware", "--print-build-logs"])
    files : List<&2, String> <- Posix.list_entries("result")
    +sorted : List<&2, String> = List.sort(~String, ~String.is_le, files)
    finish_firmware_build(suffix_files(sorted, ".hex", []), suffix_files(sorted, ".md5", []), root ++ "/config/ergodox")

def edit_firmware(+root: String, editor: String) -> IO(Unit):
  match editor:
    case SNil{}:
      do IO<Unit>:
        IO.print("Keymap source: " ++ root ++ "/packages/ergodox-firmware/src\n")
        OS.checked(["ls", "-la", root ++ "/packages/ergodox-firmware/src"])
        IO.print("\nSet $EDITOR to open in your preferred editor")
    case editor:
      OS.checked(["bash", "-c", "exec $EDITOR \"$1\"", "hey-editor", root ++ "/packages/ergodox-firmware/src"])

def flash_selected(hex: String, gui: Bool, loader: Bool) -> IO(Unit):
  match gui loader:
    case True{} loader:
      do IO<Unit>:
        IO.print("Opening Keymapp...\n\nTo flash:\n  1. Click 'Flash from file' in Keymapp\n  2. Select: " ++ hex ++ "\n  3. Press reset button on keyboard when prompted\n")
        OS.checked(["open", "-a", "Keymapp"])
    case False{} True{}:
      do IO<Unit>:
        IO.print("WARNING: teensy-loader-cli may fail on macOS (USB driver conflict)\nConsider installing Keymapp: brew install --cask keymapp\n")
        answer : String <- Posix.read_line("Press reset button on keyboard, then press Enter...")
        OS.checked(["teensy_loader_cli", "-mmcu=atmega32u4", "-w", hex])
    case False{} False{}:
      IO.die(Unit, 1, "No flashing tool found. Install Keymapp: brew install --cask keymapp")

def flash_existing(+hex: String, exists: Bool) -> IO(Unit):
  match exists:
    case False{}:
      IO.die(Unit, 1, "Firmware not found: " ++ hex ++ ". Run 'hey ergodox-build' first.")
    case True{}:
      do IO<Unit>:
        IO.print("Flashing ErgoDox firmware: " ++ hex ++ "\n")
        gui : Bool <- Posix.path_exists("/Applications/Keymapp.app")
        loader : Bool <- Posix.command_exists("teensy_loader_cli")
        flash_selected(hex, gui, loader)

def flash_firmware(root: String, hex: String) -> IO(Unit):
  do IO<Unit>:
    +path : String = Context.default_value(hex, root ++ "/config/ergodox/zsa_ergodox_ez_m32u4_base_ergo-drifter.hex")
    exists : Bool <- Posix.path_exists(path)
    flash_existing(path, exists)

def print_config(result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.write(out)
    case result:
      IO.pure(Unit, Unit{})

def firmware_info(+root: String) -> IO(Unit):
  do IO<Unit>:
    IO.print(Text.concat_task_text(["ErgoDox EZ - Ergo Drifter Layout\n================================\n\nBuild System: Pure nix (no ~/qmk_firmware required)\n\nKeymap source:\n  ", root, "/packages/ergodox-firmware/src/\n\nBuilt firmware:\n  ", root, "/config/ergodox/zsa_ergodox_ez_m32u4_base_ergo-drifter.hex\n\nCommands:\n  hey ergodox-build       Build firmware with nix\n  hey ergodox-flash       Flash to keyboard (Keymapp GUI)\n  hey ergodox-build-flash Build and flash\n  hey ergodox-edit        Edit keymap source\n  hey ergodox-draw        Generate layout SVG\n\nCurrent config:"]))
    result : OS.ProcessResult <- OS.run(["grep", "-E", "DEBOUNCE|TAPPING_TERM", root ++ "/packages/ergodox-firmware/src/config.h"], True{})
    print_config(result)
    IO.print("\nOryx configurator:\n  https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL")

def nix_repl(+root: String) -> IO(Unit):
  do IO<Unit>:
    Posix.change_directory(root)
    +directory : String <- Posix.temporary_directory()
    cleanup : U32 <- Resources.defer_command(["rm", "-rf", "--", directory])
    +path : String = directory ++ "/repl.nix"
    Posix.write_text(path, "(builtins.getFlake " ++ Policy.nix_string_literal(root) ++ ")")
    OS.checked(["nix", "repl", "<nixpkgs>", path])

def remove_skill_leaks(names: List<&2, String>, +global: String) -> IO(Unit):
  match names:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case +name <> rest:
      do IO<Unit>:
        IO.print("removing leaked project-local skill from global target: " ++ name)
        OS.checked(["chmod", "-R", "u+w", global ++ "/" ++ name])
        OS.checked(["rm", "-rf", "--", global ++ "/" ++ name])
        remove_skill_leaks(rest, global)

def clean_selected_skills(names: List<&2, String>, global: String) -> IO(Unit):
  match names:
    case Nil{}:
      IO.print("no dotfiles project-local skill leaks found in ~/.agents/skills")
    case +first <> +rest:
      do IO<Unit>:
        count : Nat = List.length(&2, String, first <> rest)
        remove_skill_leaks(first <> rest, global)
        IO.print("removed " ++ Nat.show(count) ++ " leaked project-local skills from ~/.agents/skills")

def clean_skill_leaks(root: String) -> IO(Unit):
  do IO<Unit>:
    +home : String <- OS.required_environment("HOME")
    names : List<&2, String> <- Guards.local_skill_leaks(root, home)
    clean_selected_skills(names, home ++ "/.agents/skills")

def run_zunit_paths(paths: List<&2, String>) -> IO(Unit):
  match paths:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case path <> rest:
      do IO<Unit>:
        OS.checked(["zunit", path])
        run_zunit_paths(rest)

def test_discovered_zsh(paths: List<&2, String>) -> IO(Unit):
  match paths:
    case Nil{}:
      IO.die(Unit, 1, "hey: no .zunit tests found under config")
    case path <> rest:
      run_zunit_paths(path <> rest)

def test_zsh_arguments(root: String, args: List<&2, String>) -> IO(Unit):
  match args:
    case Nil{}:
      do IO<Unit>:
        listing : String <- OS.output(["find", root ++ "/config", "-name", "*.zunit", "-print0"])
        paths : List<&2, String> = List.sort(~String, ~String.is_le, Text.nul_separated_paths(listing))
        test_discovered_zsh(paths)
    case args:
      OS.checked(OS.linear_arguments("zunit" <> args))

def test_zsh(+root: String, args: List<&2, String>, available: Bool) -> IO(Unit):
  match available:
    case False{}:
      IO.die(Unit, 1, "zunit not found. Install with: brew install zunit-zsh/zunit/zunit")
    case True{}:
      do IO<Unit>:
        Posix.change_directory(root)
        test_zsh_arguments(root, args)

def benchmark_mode(mode: BenchmarkMode) -> String:
  match mode:
    case RunBenchmark{}:
      "run"
    case CheckBenchmark{}:
      "check"
    case CompareBenchmark{}:
      "compare"
    case SaveBenchmark{}:
      "save"

def benchmark_revision(result: OS.ProcessResult) -> String:
  match result:
    case OS.ProcessResult{0, out, error}:
      String.trim(out)
    case result:
      "unknown"

def write_benchmark_raw(path: String, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{status, out, error}:
      Posix.write_text(path, out)

def benchmark_zsh(ctx: Context.TaskContext, mode: BenchmarkMode, args: List<&2, String>, available: Bool) -> IO(Unit):
  match ctx available:
    case ctx False{}:
      IO.die(Unit, 1, "zsh-bench not on PATH; rebuild so modules.shell.zsh installs pkgs.my.zsh-bench")
    case Context.TaskContext{+root, host, platform} True{}:
      do IO<Unit>:
        IO.print("==> Running zsh-bench (16 iterations)...")
        +raw : OS.ProcessResult <- OS.run(OS.linear_arguments("zsh-bench" <> args), True{})
        OS.check(raw)
        revision : OS.ProcessResult <- OS.run(["git", "-C", root, "rev-parse", "--short", "HEAD"], True{})
        +directory : String <- Posix.temporary_directory()
        cleanup : U32 <- Resources.defer_command(["rm", "-rf", "--", directory])
        +path : String = directory ++ "/benchmark.txt"
        write_benchmark_raw(path, raw)
        report : OS.ProcessResult <- OS.run_with_input([root ++ "/bin/zbench-report", "--mode", benchmark_mode(mode), "--host", host, "--dir", root ++ "/benchmarks/zsh-bench", "--git-rev", benchmark_revision(revision)], False{}, path)
        OS.check(report)

def approved_cache_block() -> String:
  "# BEGIN dotfiles binary caches\nexperimental-features = nix-command flakes\nsubstituters = https://cache.nixos.org https://nix-community.cachix.org https://hyprland.cachix.org https://cosmic.cachix.org/ https://cache.numtide.com\ntrusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0H4HLrtLxA0fK5nQ1rG6Rt4p6MxY5U= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc= cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE= niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=\n# END dotfiles binary caches"

def restart_nix_daemon(platform: String) -> IO(Unit):
  match platform:
    case "Darwin":
      OS.checked(["sudo", "launchctl", "kickstart", "-k", "system/org.nixos.nix-daemon"])
    case platform:
      OS.checked(["sudo", "systemctl", "restart", "nix-daemon"])

def apply_cache_block(+path: String) -> IO(Unit):
  do IO<Unit>:
    +directory : String <- Posix.temporary_directory()
    cleanup : U32 <- Resources.defer_command(["rm", "-rf", "--", directory])
    +payload : String = directory ++ "/cache-block.txt"
    Posix.write_text(payload, "\n" ++ approved_cache_block() ++ "\n")
    parent : String <- OS.output(["dirname", path])
    OS.checked(["sudo", "mkdir", "-p", parent])
    OS.checked(["sudo", "touch", path])
    appended : OS.ProcessResult <- OS.run_with_input(["sudo", "tee", "-a", path], True{}, payload)
    OS.check(appended)
    platform : String <- Posix.platform_name()
    restart_nix_daemon(platform)
    IO.print("Nix cache bootstrap complete. You can now run `hey re`.")

def confirm_cache_write(path: String, answer: String) -> IO(Unit):
  match answer:
    case "yes":
      apply_cache_block(path)
    case answer:
      IO.print("aborted")

def offer_cache_write(+path: String, mode: CacheMode) -> IO(Unit):
  match mode:
    case PreviewCaches{}:
      IO.print(Text.concat_task_text(["Dry run. Re-run with `hey setup-caches --apply` to write:\n  ", path, "\n\n", approved_cache_block()]))
    case ApplyCaches{}:
      do IO<Unit>:
        answer : String <- Posix.read_line("Append this managed block to /etc/nix/nix.conf? Type 'yes' to continue: ")
        confirm_cache_write(path, answer)

def present_caches(+path: String, mode: CacheMode, present: Bool) -> IO(Unit):
  match present:
    case True{}:
      IO.print("dotfiles cache block already present in " ++ path)
    case False{}:
      do IO<Unit>:
        IO.print("This bootstraps only the dotfiles-approved Nix binary caches:\n  - cache.nixos.org\n  - nix-community.cachix.org\n  - hyprland.cachix.org\n  - cosmic.cachix.org\n  - cache.numtide.com (llm-agents.nix)\n\nIt does NOT enable accept-flake-config, so random flakes cannot add trusted caches.\n")
        offer_cache_write(path, mode)

def existing_cache_config(path: String, exists: Bool) -> IO(String):
  match exists:
    case True{}:
      Posix.read_text(path)
    case False{}:
      IO.pure(String, "")

def configure_caches(mode: CacheMode) -> IO(Unit):
  do IO<Unit>:
    +path : String = "/etc/nix/nix.conf"
    exists : Bool <- Posix.path_exists(path)
    current : String <- existing_cache_config(path, exists)
    present_caches(path, mode, String.contains(current, "# BEGIN dotfiles binary caches"))

def execute_context_task(ctx: Context.TaskContext, task: ContextDesktopTask) -> IO(Unit):
  match ctx task:
    case Context.TaskContext{root, host, platform} BuildFirmware{}:
      build_firmware(root)
    case Context.TaskContext{root, host, platform} EditFirmware{}:
      do IO<Unit>:
        editor : String <- OS.env("EDITOR")
        edit_firmware(root, editor)
    case Context.TaskContext{root, host, platform} FlashFirmware{hex}:
      flash_firmware(root, hex)
    case Context.TaskContext{+root, host, platform} DrawFirmware{}:
      do IO<Unit>:
        IO.print("Generating keymap visualization...")
        OS.checked(["uvx", "--from", "keymap-drawer", "keymap", "draw", root ++ "/config/ergodox/keymap.yaml", "-o", root ++ "/config/ergodox/layout.svg"])
        IO.print("Generated: " ++ root ++ "/config/ergodox/layout.svg")
    case Context.TaskContext{root, host, platform} FirmwareInfo{}:
      firmware_info(root)
    case Context.TaskContext{root, host, platform} NixRepl{}:
      nix_repl(root)
    case Context.TaskContext{+root, host, platform} SynchronizeSkillkit{}:
      do IO<Unit>:
        result : OS.ProcessResult <- OS.run_with_environment([root ++ "/bin/skillkit-sync"], False{}, "DOTFILES", root)
        OS.check(result)
    case Context.TaskContext{root, host, platform} CleanSkillLeaks{}:
      clean_skill_leaks(root)
    case Context.TaskContext{root, host, platform} TestZsh{args}:
      do IO<Unit>:
        available : Bool <- Posix.command_exists("zunit")
        test_zsh(root, args, available)
    case ctx BenchmarkZsh{mode, args}:
      do IO<Unit>:
        available : Bool <- Posix.command_exists("zsh-bench")
        benchmark_zsh(ctx, mode, args, available)

def execute_desktop_task(task: DesktopTask) -> IO(Unit):
  match task:
    case ContextOperation{operation}:
      do IO<Unit>:
        ctx : Context.TaskContext <- Context.task_context()
        execute_context_task(ctx, operation)
    case ConfigureCaches{mode}:
      configure_caches(mode)
    case InvalidDesktopArguments{}:
      IO.die(Unit, 2, "hey: invalid task arguments; use --help for usage")
