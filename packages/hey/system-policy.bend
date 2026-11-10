import Base
import ./posix.bend as Posix

type DarwinPlan is Data:
  UserBuild{}
  PrebuiltSwitch{}
  PrebuiltCheck{}
  UpstreamAction{action: String}

def agent_mode(+agent: String, +pi: String, claude: String) -> Bool:
  Bool.or(String.eq(agent, "1"), Bool.or(String.eq(pi, "true"), String.eq(claude, "1")))

def rebuild_flags(agent: Bool) -> List<&2, String>:
  match agent:
    case True{}:
      ["--no-write-lock-file", "--show-trace"]
    case False{}:
      ["--no-write-lock-file"]

def passthrough_flag(arg: String) -> Bool:
  match arg:
    case "--flake":
      True{}
    case "--no-flake":
      True{}
    case "-p":
      True{}
    case "--profile-name":
      True{}
    case "--rollback":
      True{}
    case "-G":
      True{}
    case "--switch-generation":
      True{}
    case "--list-generations":
      True{}
    case "--dry-run":
      True{}
    case arg:
      False{}

def has_passthrough_flag(args: List<&2, String>) -> Bool:
  match args:
    case Nil{}:
      False{}
    case arg <> rest:
      Bool.or(passthrough_flag(arg), has_passthrough_flag(rest))

def plan_darwin_action(action: String) -> DarwinPlan:
  match action:
    case "switch":
      PrebuiltSwitch{}
    case "check":
      PrebuiltCheck{}
    case "build":
      UserBuild{}
    case action:
      UpstreamAction{action}

def choose_darwin_plan(action: String, passthrough: Bool) -> DarwinPlan:
  match passthrough:
    case True{}:
      UpstreamAction{action}
    case False{}:
      plan_darwin_action(action)

def darwin_plan(action: String, args: List<&2, String>) -> DarwinPlan:
  choose_darwin_plan(action, has_passthrough_flag(args))

def escape_nix_interpolation(text: String) -> String:
  match text:
    case SNil{}:
      ""
    case SCon{Chr{36}, SCon{Chr{123}, rest}}:
      "\\${" ++ escape_nix_interpolation(rest)
    case SCon{head, rest}:
      SCon{head, escape_nix_interpolation(rest)}

def nix_string_literal(text: String) -> String:
  escape_nix_interpolation(String.quote(text))

def render_prebuilt_flake(derivation: String, path: String) -> String:
  "{\n  outputs = _: {\n    darwinConfigurations.hey.system = {\n      type = \"derivation\";\n      name = \"darwin-system\";\n      outputName = \"out\";\n      outputs = [ \"out\" ];\n      drvPath = builtins.storePath " ++ nix_string_literal(derivation) ++ ";\n      outPath = builtins.storePath " ++ nix_string_literal(path) ++ ";\n    };\n  };\n}\n"

def warning_if(condition: Bool, message: String) -> List<&2, String>:
  match condition:
    case True{}:
      [message]
    case False{}:
      []

# Half-percent thresholds avoid overflowing a full memory count times 100.
def rounded_percent_threshold(+total: U32, percent: U32) -> U32:
  +weight = (2 * percent - 1 : U32)
  (total / 200 * weight + (U32.mod(total, 200) * weight + 199) / 200 : U32)

def rounded_percent_search(fuel: Nat, +total: U32, +used: U32, +current: U32) -> U32:
  match fuel:
    case 0n:
      current
    case 1n+rest:
      +next = (current + 1 : U32)
      Bool.pick(U32, (used >= rounded_percent_threshold(total, next) : U32), rounded_percent_search(rest, total, used, next), current)

def swap_warning(total: U32, +used: U32) -> List<&2, String>:
  match total:
    case 0:
      []
    case +total:
      +percent = rounded_percent_search(100n, total, used, 0)
      warning_if((percent >= 85 : U32), "swap is " ++ U32.show(percent) ++ "% full (" ++ U32.show(used) ++ " MiB of " ++ U32.show(total) ++ " MiB)")

def available_warning(total: U32, +available: U32) -> List<&2, String>:
  match total:
    case 0:
      []
    case +total:
      warning_if((available < total / 10 + Bool.to_u32(U32.is_gt(U32.mod(total, 10), 0)) : U32), "only " ++ U32.show(available) ++ " MiB of " ++ U32.show(total) ++ " MiB memory is available")

def pressure_warning_high(level: U32, critical: Bool) -> List<&2, String>:
  match critical:
    case True{}:
      ["macOS reports CRITICAL memory pressure"]
    case False{}:
      warning_if((level >= 2 : U32), "macOS reports memory pressure (warn)")

def evaluator_warnings(evaluators: List<&2, String>) -> List<&2, String>:
  match evaluators:
    case Nil{}:
      []
    case +head <> +rest:
      (Nat.show(1n+List.length(&2, String, rest)) ++ " other full-system evaluation(s) running:") <> head <> rest

def memory_warnings(memory: Posix.SystemMemory, evaluators: List<&2, String>) -> List<&2, String>:
  match memory:
    case Posix.SystemMemory{+total, available, swap_total, swap_used, +level}:
      List.concat(&2, String, [swap_warning(swap_total, swap_used), available_warning(total, available), pressure_warning_high(level, (level >= 4 : U32)), evaluator_warnings(evaluators)])
