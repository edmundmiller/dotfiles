import Base

type PidDigits is Data:
  ReadingPid{value: U32, seen: Bool}
  ParsedPid{value: U32}
  InvalidPid{}

def finish_pid(value: U32, valid: Bool) -> PidDigits:
  match valid:
    case True{}:
      ParsedPid{value}
    case False{}:
      InvalidPid{}

def append_pid_digit(value: U32, digit: U32, fits: Bool) -> PidDigits:
  match fits:
    case True{}:
      ReadingPid{(value * 10 + digit : U32), True{}}
    case False{}:
      InvalidPid{}

def read_pid_digit(+value: U32, +digit: U32) -> PidDigits:
  append_pid_digit(value, digit, Bool.or(U32.is_lt(value, 214748364), Bool.and(U32.is_eq(value, 214748364), U32.is_le(digit, 7))))

def classify_pid_char(+value: U32, seen: Bool, head: Char, ended: Bool, digit: Bool) -> PidDigits:
  match ended digit:
    case True{} digit:
      finish_pid(value, Bool.and(seen, U32.is_gt(value, 0)))
    case False{} True{}:
      read_pid_digit(value, (Char.to_u32(head) - 48 : U32))
    case False{} False{}:
      InvalidPid{}

def scan_pid_digits(text: String, state: PidDigits, +terminator: Char) -> Maybe<&2, U32>:
  match text state:
    case text ParsedPid{value}:
      Some{value}
    case text InvalidPid{}:
      None{}
    case SNil{} ReadingPid{value, seen}:
      None{}
    case SCon{+head, rest} ReadingPid{value, seen}:
      scan_pid_digits(rest, classify_pid_char(value, seen, head, Char.is_eq(head, terminator), Char.is_digit(head)), terminator)

def assigned_pid(text: String) -> Maybe<&2, U32>:
  match text:
    case SCon{Chr{61}, rest}:
      scan_pid_digits(String.trim_start(rest), ReadingPid{0, False{}}, Chr{59})
    case text:
      None{}

def launch_pid_if(text: String, prefix: Bool) -> Maybe<&2, U32>:
  match prefix:
    case True{}:
      assigned_pid(String.trim_start(String.drop(text, 5n)))
    case False{}:
      None{}

def launch_pid(+text: String) -> Maybe<&2, U32>:
  launch_pid_if(text, String.starts_with(text, "\"PID\""))

def parent_pid_space(text: String, space: Bool) -> Maybe<&2, U32>:
  match space:
    case True{}:
      scan_pid_digits(String.trim_start(text), ReadingPid{0, False{}}, Chr{41})
    case False{}:
      None{}

def parent_pid_rest(text: String) -> Maybe<&2, U32>:
  match text:
    case SCon{+head, +rest}:
      parent_pid_space(SCon{head, rest}, Char.is_space(head))
    case SNil{}:
      None{}

def parent_pid_if(text: String, prefix: Bool) -> Maybe<&2, U32>:
  match prefix:
    case True{}:
      parent_pid_rest(String.drop(text, 4n))
    case False{}:
      None{}

def parent_pid(+text: String) -> Maybe<&2, U32>:
  parent_pid_if(text, String.starts_with(text, "(PID"))

def first_pid(existing: Maybe<&2, U32>, candidate: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match existing:
    case Some{value}:
      Some{value}
    case None{}:
      candidate

def scan_gateway_status(text: String, launch: Maybe<&2, U32>, parent: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match text launch:
    case text Some{value}:
      Some{value}
    case SNil{} None{}:
      parent
    case SCon{+head, +rest} None{}:
      +current : String = SCon{head, rest}
      scan_gateway_status(rest, launch_pid(current), first_pid(parent, parent_pid(current)))

def gateway_pid(text: String) -> Maybe<&2, U32>:
  scan_gateway_status(text, None{}, None{})
