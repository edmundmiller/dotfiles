import Base
import ./os.bend as OS

def user_character(+character: Char) -> Bool:
  +value = Char.to_u32(character)
  Bool.or(Bool.or(Bool.and(U32.is_le(48, value), U32.is_le(value, 57)), Bool.and(U32.is_le(65, value), U32.is_le(value, 90))), Bool.or(Bool.and(U32.is_le(97, value), U32.is_le(value, 122)), Bool.or(Char.is_eq(character, '.'), Bool.or(Char.is_eq(character, '_'), Char.is_eq(character, '-')))))

def user_characters(text: String, fuel: Nat) -> Bool:
  match text fuel:
    case SNil{} fuel:
      True{}
    case text 0n:
      False{}
    case SCon{head, rest} 1n+remaining:
      Bool.and(user_character(head), user_characters(rest, remaining))

def user_value(value: String, valid: Bool) -> IO(String):
  match value valid:
    case SNil{} valid:
      IO.pure(String, "user")
    case value True{}:
      IO.pure(String, value)
    case value False{}:
      IO.die(String, 1, "NUC snapshot user must contain at most 128 letters, digits, dots, underscores or hyphens")

def snapshot_user() -> IO(String):
  do IO<String>:
    +value : String <- OS.env("USER")
    user_value(value, user_characters(value, 128n))

def require_user(value: String) -> IO(String):
  match value:
    case SNil{}:
      IO.die(String, 2, "Native snapshot user must not be empty")
    case +value:
      user_value(value, user_characters(value, 128n))
