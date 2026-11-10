import Base
import ./os.bend as OS
import ./posix.bend as Posix

def include_path(directory: String, rest: String, exists: Bool) -> String:
  match exists:
    case True{}:
      directory ++ ":" ++ rest
    case False{}:
      rest

def privileged_path(directories: List<&2, String>, current: String) -> IO(String):
  match directories:
    case Nil{}:
      IO.pure(String, current)
    case Con{+directory, tail}:
      do IO<String>:
        exists : Bool <- Posix.path_exists(directory)
        rest : String <- privileged_path(tail, current)
        return include_path(directory, rest, exists)

def run_privileged(argv: List<String>) -> IO(Unit):
  do IO<Unit>:
    current : String <- OS.env("PATH")
    path : String <- privileged_path(["/run/wrappers/bin", "/run/current-system/sw/bin", "/nix/var/nix/profiles/default/bin"], current)
    result : OS.ProcessResult <- OS.run_with_environment(argv, False{}, "PATH", path)
    OS.check(result)
