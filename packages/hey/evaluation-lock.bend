import Base
import ./os.bend as OS
import ./posix.bend as Posix
import ./resources.bend as Resources
import ./task-context.bend as Context

type OwnerObservation is Data:
  OwnerObservation{identity: String, contents: String}

type EvaluationLease is Type:
  EvaluationLease{path: String, cleanup: U32}

type LockPhase is Data:
  CreateDirectory{}
  WriteOwner{}
  InspectDirectory{status: U32, error: String}
  ReadOwner{}
  ProbeOwner{pid: U32, observation: OwnerObservation}
  ProbeLiveness{pid: U32, observation: OwnerObservation}
  UnknownOwner{identity: String}
  ReclaimOwner{identity: String}
  WaitForOwner{description: String}
  AcquiredOwner{cleanup: U32}
  LockFailure{status: U32, error: String}

def nonzero_pid(pid: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match pid:
    case Some{0}:
      None{}
    case pid:
      pid

def pid_field(key: String, value: String) -> Maybe<&2, U32>:
  match key:
    case "{pid":
      nonzero_pid(U32.read(String.trim(value)))
    case "{\"pid\"":
      nonzero_pid(U32.read(String.trim(value)))
    case key:
      None{}

def pid_parts(parts: List<&2, String>) -> Maybe<&2, U32>:
  match parts:
    case key <> value <> Nil{}:
      pid_field(String.trim(key), value)
    case parts:
      None{}

def owner_pid(fields: List<&2, String>) -> Maybe<&2, U32>:
  match fields:
    case field <> rest:
      pid_parts(String.split(field, Chr{58}))
    case Nil{}:
      None{}

def parse_owner_pid(contents: String) -> Maybe<&2, U32>:
  owner_pid(String.split(contents, Chr{44}))

def observation_identity(observation: OwnerObservation) -> String:
  match observation:
    case OwnerObservation{identity, contents}:
      identity

def observation_description(pid: U32, observation: OwnerObservation) -> String:
  match observation:
    case OwnerObservation{identity, contents}:
      "pid " ++ U32.show(pid) ++ " " ++ contents

def owner_phase(+observation: OwnerObservation, pid: Maybe<&2, U32>) -> LockPhase:
  match pid:
    case Some{pid}:
      ProbeOwner{pid, observation}
    case None{}:
      UnknownOwner{observation_identity(observation)}

def read_owner_result(identity: String, result: OS.ProcessResult) -> LockPhase:
  match result:
    case OS.ProcessResult{0, +owner, error}:
      owner_phase(OwnerObservation{identity, owner}, parse_owner_pid(owner))
    case result:
      UnknownOwner{identity}

def create_result(result: OS.ProcessResult) -> LockPhase:
  match result:
    case OS.ProcessResult{0, out, error}:
      WriteOwner{}
    case OS.ProcessResult{status, out, error}:
      InspectDirectory{status, error}

def directory_phase(status: U32, error: String, exists: Bool) -> LockPhase:
  match exists:
    case True{}:
      ReadOwner{}
    case False{}:
      LockFailure{status, error}

def live_owner_phase(pid: U32, observation: OwnerObservation, alive: Bool) -> LockPhase:
  match alive:
    case True{}:
      WaitForOwner{observation_description(pid, observation)}
    case False{}:
      ReclaimOwner{observation_identity(observation)}

def observed_start_matches(observation: OwnerObservation, start: String) -> Bool:
  match observation:
    case OwnerObservation{identity, +contents}:
      Bool.or(String.contains(contents, String.quote(start)), String.contains(contents, "started: \"\""))

def start_probe_phase(pid: U32, +observation: OwnerObservation, start: String) -> LockPhase:
  match start:
    case SNil{}:
      ProbeLiveness{pid, observation}
    case start:
      live_owner_phase(pid, observation, observed_start_matches(observation, start))

def process_probe_result(pid: U32, observation: OwnerObservation, result: OS.ProcessResult) -> LockPhase:
  match result:
    case OS.ProcessResult{0, out, error}:
      start_probe_phase(pid, observation, String.trim(out))
    case result:
      ProbeLiveness{pid, observation}

def unknown_owner_phase(identity: String, old: Bool) -> LockPhase:
  match old:
    case True{}:
      ReclaimOwner{identity}
    case False{}:
      WaitForOwner{"an unidentified process"}

def owner_age_result(identity: String, result: OS.ProcessResult) -> LockPhase:
  match result:
    case OS.ProcessResult{0, out, error}:
      unknown_owner_phase(identity, Bool.not(String.is_empty(String.trim(out))))
    case result:
      WaitForOwner{"an unidentified process"}

def process_start(result: OS.ProcessResult) -> String:
  match result:
    case OS.ProcessResult{0, out, error}:
      String.trim(out)
    case result:
      ""

def lock_notice(path: String, description: String, show: Bool) -> IO(Unit):
  match show:
    case True{}:
      do IO<Unit>:
        IO.print_err("hey: waiting for the system-evaluation lock held by " ++ description)
        IO.print_err("hey: lock path " ++ path ++ "; Ctrl-C to stop waiting")
    case False{}:
      IO.pure(Unit, Unit{})

def remove_renamed_lock(stale: String, renamed: Bool) -> IO(Unit):
  match renamed:
    case True{}:
      OS.checked(["rm", "-rf", "--", stale])
    case False{}:
      IO.pure(Unit, Unit{})

def write_owner(+path: String, label: String) -> IO(U32):
  do IO<U32>:
    cleanup : U32 <- Resources.defer_command(["rm", "-rf", "--", path])
    +pid : U32 <- Posix.process_id()
    cwd : String <- Posix.current_directory()
    probe : OS.ProcessResult <- OS.run(["ps", "-o", "lstart=", "-p", U32.show(pid)], True{})
    acquired : String <- OS.output(["date", "+%Y-%m-%dT%H:%M:%S%z"])
    Posix.write_text(path ++ "/owner.nuon", "{pid: " ++ U32.show(pid) ++ ", started: " ++ String.quote(process_start(probe)) ++ ", label: " ++ String.quote(label) ++ ", cwd: " ++ String.quote(cwd) ++ ", acquired: " ++ String.quote(acquired) ++ "}")
    return cleanup

def lock_step(+path: String, label: String, notice: U32, phase: LockPhase) -> IO(LockPhase):
  match phase:
    case CreateDirectory{}:
      do IO<LockPhase>:
        result : OS.ProcessResult <- OS.run(["mkdir", path], True{})
        return create_result(result)
    case WriteOwner{}:
      do IO<LockPhase>:
        cleanup : U32 <- write_owner(path, label)
        return AcquiredOwner{cleanup}
    case InspectDirectory{status, error}:
      do IO<LockPhase>:
        exists : Bool <- Posix.path_exists(path)
        return directory_phase(status, error, exists)
    case ReadOwner{}:
      do IO<LockPhase>:
        identity : String <- Posix.path_identity(path)
        result : OS.ProcessResult <- OS.run(["cat", path ++ "/owner.nuon"], True{})
        return read_owner_result(identity, result)
    case ProbeOwner{+pid, observation}:
      do IO<LockPhase>:
        result : OS.ProcessResult <- OS.run(["ps", "-o", "lstart=", "-p", U32.show(pid)], True{})
        return process_probe_result(pid, observation, result)
    case ProbeLiveness{+pid, observation}:
      do IO<LockPhase>:
        alive : Bool <- Posix.process_alive(pid)
        return live_owner_phase(pid, observation, alive)
    case UnknownOwner{identity}:
      do IO<LockPhase>:
        result : OS.ProcessResult <- OS.run(["find", path, "-maxdepth", "0", "-mmin", "+1"], True{})
        return owner_age_result(identity, result)
    case ReclaimOwner{identity}:
      do IO<LockPhase>:
        IO.print_err("hey: reclaiming stale system-evaluation lock")
        pid : U32 <- Posix.process_id()
        +stale : String = path ++ ".stale-" ++ U32.show(pid)
        renamed : Bool <- Posix.rename_if_unchanged(path, stale, identity)
        remove_renamed_lock(stale, renamed)
        return CreateDirectory{}
    case WaitForOwner{description}:
      do IO<LockPhase>:
        lock_notice(path, description, U32.is_eq(U32.mod(notice, 30), 0))
        OS.checked(["sleep", "2"])
        return CreateDirectory{}
    case AcquiredOwner{cleanup}:
      IO.pure(LockPhase, AcquiredOwner{cleanup})
    case LockFailure{status, error}:
      IO.die(LockPhase, status, error)

def count_notice(phase: LockPhase, notice: U32) -> U32:
  match phase:
    case WaitForOwner{description}:
      (notice + 1 : U32)
    case phase:
      notice

def lock_loop(fuel: Nat, +path: String, +label: String, +notice: U32, phase: LockPhase) -> IO(U32):
  match fuel phase:
    case fuel AcquiredOwner{cleanup}:
      IO.pure(U32, cleanup)
    case 0n phase:
      IO.die(U32, 75, "hey: system-evaluation lock wait exhausted")
    case 1n+rest +phase:
      do IO<U32>:
        next : LockPhase <- lock_step(path, label, notice, phase)
        lock_loop(rest, path, label, count_notice(phase, notice), next)

def acquire_evaluation_lock(label: String) -> IO(EvaluationLease):
  do IO<EvaluationLease>:
    home : String <- OS.required_environment("HOME")
    cache : String <- OS.env("XDG_CACHE_HOME")
    +directory : String = Context.default_value(cache, home ++ "/.cache") ++ "/hey"
    OS.checked(["mkdir", "-p", directory])
    +path : String = directory ++ "/system-eval.lock"
    cleanup : U32 <- lock_loop(100000n, path, label, 0, CreateDirectory{})
    return EvaluationLease{path, cleanup}

def release_evaluation_lock(lease: EvaluationLease) -> IO(Unit):
  match lease:
    case EvaluationLease{path, cleanup}:
      do IO<Unit>:
        OS.checked(["rm", "-rf", "--", path])
        Resources.cancel_cleanup(cleanup)
