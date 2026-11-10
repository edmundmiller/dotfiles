import Base

def append_reversed_text(text: String, reversed: String) -> String:
  match text:
    case SNil{}:
      reversed
    case SCon{head, rest}:
      append_reversed_text(rest, SCon{head, reversed})

def concat_task_chunks(chunks: List<&2, String>, reversed: String) -> String:
  match chunks:
    case Nil{}:
      String.reverse(reversed)
    case chunk <> rest:
      concat_task_chunks(rest, append_reversed_text(chunk, reversed))

def concat_task_text(chunks: List<&2, String>) -> String:
  concat_task_chunks(chunks, "")

def append_replacement(hit: Bool, head: Char, value: String, reversed: String) -> String:
  match hit:
    case True{}:
      append_reversed_text(value, reversed)
    case False{}:
      SCon{head, reversed}

def replace_task_scan(text: String, +key: String, +value: String, +key_rest: Nat, reversed: String, skip: Nat) -> String:
  match text skip:
    case SNil{} skip:
      String.reverse(reversed)
    case SCon{head, rest} 1n+skip:
      replace_task_scan(rest, key, value, key_rest, reversed, skip)
    case SCon{+head, +rest} 0n:
      +hit = String.starts_with(SCon{head, rest}, key)
      replace_task_scan(rest, key, value, key_rest, append_replacement(hit, head, value, reversed), Bool.pick(Nat, hit, key_rest, 0n))

def replace_task_text(text: String, key: String, value: String) -> String:
  match key:
    case SNil{}:
      text
    case SCon{+head, +rest}:
      replace_task_scan(text, SCon{head, rest}, value, String.length(rest), "", 0n)

def include_nul_path(reversed: String, paths: List<&2, String>) -> List<&2, String>:
  match reversed:
    case SNil{}:
      paths
    case reversed:
      String.reverse(reversed) <> paths

def scan_nul_paths(text: String, reversed: String, paths: List<&2, String>) -> List<&2, String>:
  match text:
    case SNil{}:
      List.reverse(&2, String, include_nul_path(reversed, paths))
    case SCon{Chr{0}, rest}:
      scan_nul_paths(rest, "", include_nul_path(reversed, paths))
    case SCon{head, rest}:
      scan_nul_paths(rest, SCon{head, reversed}, paths)

def nul_separated_paths(text: String) -> List<&2, String>:
  scan_nul_paths(text, "", [])

def quote_shell_argument(text: String) -> String:
  concat_task_text(["'", replace_task_text(text, "'", "'\\''"), "'"])
