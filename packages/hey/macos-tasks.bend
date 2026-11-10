import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./task-text.bend as Text

type XcodeAction is Data:
  PreviewXcode{}
  ApplyXcode{}

type AdminMode is Data:
  CachedAdministrator{}
  PromptAdministrator{}

type InstallLocation is Data:
  KeepLocation{}
  MoveLocation{path: String}

type XcodeTask is Data:
  SetupXcode{application: String, action: XcodeAction, admin: AdminMode, destination: Maybe<&2, String>}
  InvalidXcodeTask{}

type XcodeOption is Data:
  ApplyOption{}
  AdministratorOption{}
  DestinationOption{}
  InlineDestination{value: String}
  ApplicationOption{value: String}
  EndOptions{}
  BadOption{}

type XcodeParseState is Data:
  ReadOptions{application: Maybe<&2, String>, action: XcodeAction, admin: AdminMode, destination: Maybe<&2, String>}
  ReadDestination{application: Maybe<&2, String>, action: XcodeAction, admin: AdminMode}
  ReadApplication{application: Maybe<&2, String>, action: XcodeAction, admin: AdminMode, destination: Maybe<&2, String>}
  BadOptions{}

def classify_other_option(+value: String, inline: Bool, flag: Bool) -> XcodeOption:
  match inline flag:
    case True{} flag:
      InlineDestination{String.drop(value, 13n)}
    case False{} True{}:
      BadOption{}
    case False{} False{}:
      ApplicationOption{value}

def classify_option(value: String) -> XcodeOption:
  match value:
    case "--apply":
      ApplyOption{}
    case "--prompt-admin":
      AdministratorOption{}
    case "--install-to":
      DestinationOption{}
    case "--":
      EndOptions{}
    case +value:
      classify_other_option(value, String.starts_with(value, "--install-to="), String.starts_with(value, "-"))

def accept_application(application: Maybe<&2, String>, value: String, action: XcodeAction, admin: AdminMode, destination: Maybe<&2, String>, options: Bool) -> XcodeParseState:
  match application options:
    case None{} True{}:
      ReadOptions{Some{value}, action, admin, destination}
    case None{} False{}:
      ReadApplication{Some{value}, action, admin, destination}
    case Some{old} options:
      BadOptions{}

def accept_option(application: Maybe<&2, String>, action: XcodeAction, admin: AdminMode, destination: Maybe<&2, String>, option: XcodeOption) -> XcodeParseState:
  match option:
    case ApplyOption{}:
      ReadOptions{application, ApplyXcode{}, admin, destination}
    case AdministratorOption{}:
      ReadOptions{application, action, PromptAdministrator{}, destination}
    case DestinationOption{}:
      ReadDestination{application, action, admin}
    case InlineDestination{value}:
      ReadOptions{application, action, admin, Some{value}}
    case EndOptions{}:
      ReadApplication{application, action, admin, destination}
    case ApplicationOption{value}:
      accept_application(application, value, action, admin, destination, True{})
    case BadOption{}:
      BadOptions{}

def accept_destination(application: Maybe<&2, String>, action: XcodeAction, admin: AdminMode, value: String, flag: Bool) -> XcodeParseState:
  match flag:
    case True{}:
      BadOptions{}
    case False{}:
      ReadOptions{application, action, admin, Some{value}}

def read_xcode_option(state: XcodeParseState, +value: String) -> XcodeParseState:
  match state:
    case ReadOptions{application, action, admin, destination}:
      accept_option(application, action, admin, destination, classify_option(value))
    case ReadDestination{application, action, admin}:
      accept_destination(application, action, admin, value, String.starts_with(value, "--"))
    case ReadApplication{application, action, admin, destination}:
      accept_application(application, value, action, admin, destination, False{})
    case BadOptions{}:
      BadOptions{}

def parsed_xcode(application: Maybe<&2, String>, action: XcodeAction, admin: AdminMode, destination: Maybe<&2, String>) -> XcodeTask:
  match application:
    case None{}:
      InvalidXcodeTask{}
    case Some{path}:
      SetupXcode{path, action, admin, destination}

def finish_xcode_options(state: XcodeParseState) -> XcodeTask:
  match state:
    case ReadOptions{application, action, admin, destination}:
      parsed_xcode(application, action, admin, destination)
    case ReadApplication{application, action, admin, destination}:
      parsed_xcode(application, action, admin, destination)
    case ReadDestination{application, action, admin}:
      InvalidXcodeTask{}
    case BadOptions{}:
      InvalidXcodeTask{}

def parse_xcode_options(args: List<&2, String>, state: XcodeParseState) -> XcodeTask:
  match args:
    case Nil{}:
      finish_xcode_options(state)
    case value <> rest:
      parse_xcode_options(rest, read_xcode_option(state, value))

def task_request(name: String, args: List<&2, String>) -> XcodeTask:
  match name:
    case "xcode:setup":
      parse_xcode_options(args, ReadOptions{None{}, PreviewXcode{}, CachedAdministrator{}, None{}})
    case name:
      InvalidXcodeTask{}

type PreparedXcode is Data:
  PreparedXcode{application: String, developer: String, destination: InstallLocation, previous: String, action: XcodeAction, admin: AdminMode}

type AdministratorAction is Data:
  FirstLaunch{developer: String}
  MoveApplication{source: String, destination: String, program: String}
  SelectDeveloper{developer: String}

def administrator_arguments(mode: AdminMode, action: AdministratorAction) -> List<&2, String>:
  match mode action:
    case CachedAdministrator{} FirstLaunch{developer}:
      ["sudo", "-n", "/usr/bin/env", "DEVELOPER_DIR=" ++ developer, "/usr/bin/xcodebuild", "-runFirstLaunch"]
    case CachedAdministrator{} MoveApplication{source, destination, program}:
      ["sudo", "-n", program, "-n", "-T", source, destination]
    case CachedAdministrator{} SelectDeveloper{developer}:
      ["sudo", "-n", "/usr/bin/xcode-select", "--switch", developer]
    case PromptAdministrator{} FirstLaunch{developer}:
      ["/usr/bin/osascript", "-e", "on run argv\n  do shell script \"/usr/bin/env \" & quoted form of (\"DEVELOPER_DIR=\" & item 1 of argv) & \" /usr/bin/xcodebuild -runFirstLaunch\" with administrator privileges\nend run", developer]
    case PromptAdministrator{} MoveApplication{source, destination, program}:
      ["/usr/bin/osascript", "-e", "on run argv\n  do shell script quoted form of (item 3 of argv) & \" -n -T \" & quoted form of (item 1 of argv) & \" \" & quoted form of (item 2 of argv) with administrator privileges\nend run", source, destination, program]
    case PromptAdministrator{} SelectDeveloper{developer}:
      ["/usr/bin/osascript", "-e", "on run argv\n  do shell script \"/usr/bin/xcode-select --switch \" & quoted form of (item 1 of argv) with administrator privileges\nend run", developer]

def scoped_xcode(argv: List<&2, String>, developer: String, capture: Bool) -> IO(OS.ProcessResult):
  OS.run_with_environment(OS.linear_arguments(argv), capture, "DEVELOPER_DIR", developer)

def finish_system_metal(previous: String, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      IO.print("Xcode selected. Previous developer directory for rollback: " ++ previous)
    case result:
      IO.die(Unit, 1, "The selected Xcode cannot run Metal; inspect xcode-select -p")

def verify_system_metal(previous: String) -> IO(Unit):
  do IO<Unit>:
    result : OS.ProcessResult <- OS.run_without_environment(["/usr/bin/xcrun", "--no-cache", "metal", "--version"], False{}, "DEVELOPER_DIR")
    finish_system_metal(previous, result)

def select_developer(mode: AdminMode, +previous: String, +selected: String, changed: Bool) -> IO(Unit):
  match changed:
    case False{}:
      verify_system_metal(previous)
    case True{}:
      do IO<Unit>:
        result : OS.ProcessResult <- OS.run(OS.linear_arguments(administrator_arguments(mode, SelectDeveloper{selected})), False{})
        OS.check(result)
        verify_system_metal(previous)

def finish_move(mode: AdminMode, +previous: String, destination: String, valid_app: Bool) -> IO(Unit):
  match valid_app:
    case False{}:
      IO.die(Unit, 1, "Xcode move did not produce a full app; inspect source and destination before retrying")
    case True{}:
      do IO<Unit>:
        +selected : String = destination ++ "/Contents/Developer"
        select_developer(mode, previous, selected, Bool.not(String.eq(previous, selected)))

def verify_move(mode: AdminMode, previous: String, destination: String, valid_app: Bool, source_exists: Bool) -> IO(Unit):
  match source_exists:
    case True{}:
      IO.die(Unit, 1, "Xcode move did not remove the source; inspect source and destination before retrying")
    case False{}:
      finish_move(mode, previous, destination, valid_app)

def move_to_available(+application: String, +destination: String, +previous: String, +mode: AdminMode, exists: Bool) -> IO(Unit):
  match exists:
    case True{}:
      IO.die(Unit, 1, "Destination already exists: " ++ destination ++ "; nothing will be replaced")
    case False{}:
      do IO<Unit>:
        program : String <- OS.move_program()
        moved : OS.ProcessResult <- OS.run(OS.linear_arguments(administrator_arguments(mode, MoveApplication{application, destination, program})), False{})
        OS.check(moved)
        valid : Bool <- Posix.path_exists(destination ++ "/Contents/Developer/usr/bin/xcodebuild")
        source_exists : Bool <- Posix.path_exists(application)
        verify_move(mode, previous, destination, valid, source_exists)

def move_and_select(plan: PreparedXcode) -> IO(Unit):
  match plan:
    case PreparedXcode{application, +developer, KeepLocation{}, +previous, action, mode}:
      select_developer(mode, previous, developer, Bool.not(String.eq(previous, developer)))
    case PreparedXcode{application, developer, MoveLocation{+destination}, previous, mode_action, mode}:
      do IO<Unit>:
        exists : Bool <- Posix.path_exists(destination)
        move_to_available(application, destination, previous, mode, exists)

def verified_app_metal(plan: PreparedXcode, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      move_and_select(plan)
    case result:
      IO.die(Unit, 1, "Metal is still unavailable; open Xcode Settings > Components and install Metal Toolchain")

def verify_app_metal(plan: PreparedXcode) -> IO(Unit):
  match plan:
    case PreparedXcode{application, +developer, destination, previous, action, mode}:
      do IO<Unit>:
        result : OS.ProcessResult <- scoped_xcode(["/usr/bin/xcrun", "--no-cache", "metal", "--version"], developer, False{})
        verified_app_metal(PreparedXcode{application, developer, destination, previous, action, mode}, result)

def downloaded_metal(plan: PreparedXcode, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      verify_app_metal(plan)
    case result:
      IO.die(Unit, 1, "Metal installation failed; inspect the output and rerun hey xcode-setup")

def prepare_metal(plan: PreparedXcode, result: OS.ProcessResult) -> IO(Unit):
  match plan result:
    case plan OS.ProcessResult{0, out, error}:
      verify_app_metal(plan)
    case PreparedXcode{application, +developer, destination, previous, action, mode} result:
      do IO<Unit>:
        downloaded : OS.ProcessResult <- scoped_xcode(["/usr/bin/xcodebuild", "-downloadComponent", "MetalToolchain"], developer, False{})
        downloaded_metal(PreparedXcode{application, developer, destination, previous, action, mode}, downloaded)

def inspect_metal(plan: PreparedXcode) -> IO(Unit):
  match plan:
    case PreparedXcode{application, +developer, destination, previous, action, mode}:
      do IO<Unit>:
        result : OS.ProcessResult <- scoped_xcode(["/usr/bin/xcrun", "--no-cache", "metal", "--version"], developer, True{})
        prepare_metal(PreparedXcode{application, developer, destination, previous, action, mode}, result)

def checked_first_launch(plan: PreparedXcode, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      inspect_metal(plan)
    case result:
      IO.die(Unit, 1, "Xcode first-launch setup is incomplete; inspect the output before retrying")

def run_first_launch(plan: PreparedXcode) -> IO(Unit):
  match plan:
    case PreparedXcode{application, +developer, destination, previous, action, +mode}:
      do IO<Unit>:
        prepared : OS.ProcessResult <- OS.run(OS.linear_arguments(administrator_arguments(mode, FirstLaunch{developer})), False{})
        OS.check(prepared)
        checked : OS.ProcessResult <- scoped_xcode(["/usr/bin/xcodebuild", "-checkFirstLaunchStatus"], developer, False{})
        checked_first_launch(PreparedXcode{application, developer, destination, previous, action, mode}, checked)

def licensed_first_launch(plan: PreparedXcode, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      run_first_launch(plan)
    case result:
      IO.die(Unit, 1, "Review and accept Xcode's license in the app, then rerun hey xcode-setup")

def prepare_first_launch(plan: PreparedXcode, result: OS.ProcessResult) -> IO(Unit):
  match plan result:
    case plan OS.ProcessResult{0, out, error}:
      inspect_metal(plan)
    case PreparedXcode{application, +developer, destination, previous, action, mode} result:
      do IO<Unit>:
        license : OS.ProcessResult <- scoped_xcode(["/usr/bin/xcodebuild", "-license", "check"], developer, True{})
        licensed_first_launch(PreparedXcode{application, developer, destination, previous, action, mode}, license)

def run_xcode_action(plan: PreparedXcode) -> IO(Unit):
  match plan:
    case PreparedXcode{application, developer, destination, previous, PreviewXcode{}, mode}:
      IO.print("Dry run. Use --apply to prepare Metal and select this Xcode; --prompt-admin allows an administrator dialog.")
    case PreparedXcode{application, +developer, destination, previous, ApplyXcode{}, mode}:
      do IO<Unit>:
        first_launch : OS.ProcessResult <- scoped_xcode(["/usr/bin/xcodebuild", "-checkFirstLaunchStatus"], developer, True{})
        prepare_first_launch(PreparedXcode{application, developer, destination, previous, ApplyXcode{}, mode}, first_launch)

def checked_xcode_version(plan: PreparedXcode, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      run_xcode_action(plan)
    case result:
      IO.die(Unit, 1, "Cannot run this Xcode; open it and complete its first-launch setup")

def describe_move(destination: InstallLocation) -> IO(Unit):
  match destination:
    case KeepLocation{}:
      IO.pure(Unit, Unit{})
    case MoveLocation{path}:
      IO.print("Move Xcode to: " ++ path)

def inspect_xcode_version(plan: PreparedXcode) -> IO(Unit):
  match plan:
    case PreparedXcode{application, +developer, +destination, +previous, action, mode}:
      do IO<Unit>:
        IO.print("Current developer directory: " ++ previous)
        IO.print("Requested developer directory: " ++ developer)
        describe_move(destination)
        version : OS.ProcessResult <- scoped_xcode(["/usr/bin/xcodebuild", "-version"], developer, False{})
        checked_xcode_version(PreparedXcode{application, developer, destination, previous, action, mode}, version)

def accept_move_destination(path: String, exists: Bool) -> IO(InstallLocation):
  match exists:
    case True{}:
      IO.die(InstallLocation, 1, "Destination already exists: " ++ path ++ "; nothing will be replaced")
    case False{}:
      IO.pure(InstallLocation, MoveLocation{path})

def resolve_destination(destination: Maybe<&2, String>) -> IO(InstallLocation):
  match destination:
    case None{}:
      IO.pure(InstallLocation, KeepLocation{})
    case Some{raw}:
      do IO<InstallLocation>:
        +path : String <- Posix.absolute_path(raw)
        exists : Bool <- Posix.path_exists(path)
        accept_move_destination(path, exists)

def inspect_installed_xcode(application: String, developer: String, action: XcodeAction, mode: AdminMode, destination: Maybe<&2, String>, exists: Bool) -> IO(Unit):
  match exists:
    case False{}:
      IO.die(Unit, 1, "No full Xcode found at " ++ application ++ "; pass the path to an installed Xcode.app")
    case True{}:
      do IO<Unit>:
        install : InstallLocation <- resolve_destination(destination)
        observed : OS.ProcessResult <- OS.run_without_environment(["/usr/bin/xcode-select", "-p"], True{}, "DEVELOPER_DIR")
        previous : String <- OS.output_value(observed)
        inspect_xcode_version(PreparedXcode{application, developer, install, previous, action, mode})

def prepare_xcode(task: XcodeTask, platform: String) -> IO(Unit):
  match task platform:
    case SetupXcode{raw, action, mode, destination} "Darwin":
      do IO<Unit>:
        +application : String <- Posix.absolute_path(raw)
        +developer : String = application ++ "/Contents/Developer"
        exists : Bool <- Posix.path_exists(developer ++ "/usr/bin/xcodebuild")
        inspect_installed_xcode(application, developer, action, mode, destination, exists)
    case task platform:
      IO.die(Unit, 1, "Xcode setup is only supported on macOS")

def execute_macos_task(task: XcodeTask) -> IO(Unit):
  match task:
    case InvalidXcodeTask{}:
      IO.die(Unit, 2, "hey: invalid Xcode arguments; use --help for usage")
    case task:
      do IO<Unit>:
        platform : String <- Posix.platform_name()
        prepare_xcode(task, platform)
