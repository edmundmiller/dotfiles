import Base
import ./os.bend as OS

type GitRevision is Data:
  GitRevision{value: String}

def revision_value(revision: GitRevision) -> String:
  match revision:
    case GitRevision{value}:
      value

def hex_character(character: Char) -> Bool:
  +value : U32 = Char.to_u32(character)
  Bool.or(Bool.and(U32.is_le(48, value), U32.is_le(value, 57)), Bool.and(U32.is_le(97, value), U32.is_le(value, 102)))

def revision_characters(text: String, length: Nat) -> Bool:
  match text length:
    case SNil{} 0n:
      True{}
    case SCon{head, rest} 1n+remaining:
      Bool.and(hex_character(head), revision_characters(rest, remaining))
    case text length:
      False{}

def valid_revision(text: String) -> Bool:
  revision_characters(text, 40n)

def require_revision_value(value: String, valid: Bool) -> IO(GitRevision):
  match valid:
    case True{}:
      IO.pure(GitRevision, GitRevision{value})
    case False{}:
      IO.die(GitRevision, 1, "Expected an exact 40-character lowercase Git revision")

def require_revision(+value: String) -> IO(GitRevision):
  require_revision_value(value, valid_revision(value))

def require_clean_text(label: String, clean: Bool) -> IO(Unit):
  match clean:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, label ++ " repository is dirty; commit or stash it first")

def require_clean_status(label: String, result: OS.ProcessResult) -> IO(Unit):
  match result:
    case OS.ProcessResult{0, out, error}:
      require_clean_text(label, String.is_empty(String.trim(out)))
    case result:
      IO.die(Unit, 1, "Could not inspect " ++ label ++ " repository")

def require_clean_repository(path: String, label: String) -> IO(Unit):
  do IO<Unit>:
    result : OS.ProcessResult <- OS.run(["git", "-C", path, "status", "--porcelain=v1", "--untracked-files=normal"], True{})
    require_clean_status(label, result)
