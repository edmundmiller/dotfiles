import Base

def choose(-A: Type, condition: Bool, yes: A, no: A) -> A:
  match condition:
    case True{}:
      yes
    case False{}:
      no

def Task(-A: Type) -> Type:
  IO(Result<&1, &1, String, A>)

def Task.pure(-A: Type, value: A) -> Task(A):
  IO.pure(Result<&1, &1, String, A>, Done{value})

def Task.fail(-A: Type, message: String) -> Task(A):
  IO.pure(Result<&1, &1, String, A>, Fail{message})

def Task.next(-A: Type, -B: Type, result: Result<&1, &1, String, A>, f: A -> Task(B)) -> Task(B):
  match result:
    case Fail{error}:
      Task.fail(B, error)
    case Done{value}:
      f(value)

def Task.bind(-A: Type, -B: Type, action: Task(A), f: A -> Task(B)) -> Task(B):
  IO.bind(Result<&1, &1, String, A>, Result<&1, &1, String, B>, action, result => Task.next(A, B, result, f))

def parallel_results(-A: Type, -B: Type, a: Result<&1, &1, String, A>, b: Result<&1, &1, String, B>) -> Result<&1, &1, String, A & B>:
  match a b:
    case Fail{message} _:
      Fail{message}
    case _ Fail{message}:
      Fail{message}
    case Done{x} Done{y}:
      Done{(x, y)}

def parallel(-A: Type, -B: Type, a: Task(A), b: Task(B)) -> Task(A & B):
  do IO<Result<&1, &1, String, A & B>>:
    left : Chan(Result<&1, &1, String, A>) <- IO.fork(Result<&1, &1, String, A>, a)
    right : Chan(Result<&1, &1, String, B>) <- IO.fork(Result<&1, &1, String, B>, b)
    x : Result<&1, &1, String, A> <- IO.join(Result<&1, &1, String, A>, left)
    y : Result<&1, &1, String, B> <- IO.join(Result<&1, &1, String, B>, right)
    return parallel_results(A, B, x, y)

def require(ok: Bool, message: String) -> Task(Unit):
  match ok:
    case True{}:
      Task.pure(Unit, Unit{})
    case False{}:
      Task.fail(Unit, message)

type Command is Data:
  Command{code: U32, out: String, err: String}

def process_result(result: Result<&1, &1, U32 & String, U32 & (String & String)>) -> Command:
  match result:
    case Fail{(code, message)}:
      Command{code, "", message}
    case Done{(code, (out, err))}:
      Command{code, out, err}

def run(program: String, args: List<String>, input: String) -> IO(Command):
  do IO<Command>:
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <- Process.run(program, args, input, 67108864, 120000)
    return process_result(result)

def without_newline(+text: String) -> String:
  choose(String, String.ends_with(text, "\n"), String.take(text, Nat.sub(String.length(text), 1n)), text)

def checked(result: Command, label: String) -> Task(String):
  match result:
    case Command{code, out, err}:
      do Task<String>:
        require(U32.is_zero(code), label ++ " failed")
        return without_newline(out)

def output(+program: String, args: List<String>, input: String) -> Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : Command <- run(program, args, input)
    checked(result, program)

def git(+repo: String, args: List<String>) -> IO(Command):
  run("git", "-C" <> repo <> args, "")

def raw_result(result: Command) -> Result<&1, &1, String, String>:
  Command{code, out, err} = result
  choose(Result<&1, &1, String, String>, U32.is_zero(code), Done{out}, Fail{"git failed"})

def git_raw(repo: String, args: List<String>) -> Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : Command <- git(repo, args)
    return raw_result(result)

def git_output(repo: String, args: List<String>) -> Task(String):
  match args:
    case Nil{}:
      Task.fail(String, "git subcommand is required")
    case Con{+subcommand, tail}:
      do IO<Result<&1, &1, String, String>>:
        result : Command <- git(repo, subcommand <> tail)
        checked(result, "git " ++ subcommand)

def optional(result: Command) -> String:
  match result:
    case Command{code, out, err}:
      choose(String, U32.is_zero(code), without_newline(out), "")

def git_optional(repo: String, args: List<String>) -> Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : Command <- git(repo, args)
    Task.pure(String, optional(result))

def succeeded(result: Command) -> Bool:
  match result:
    case Command{code, out, err}:
      U32.is_zero(code)

def first(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{head, tail}:
      head

def nonempty(s: String) -> Bool:
  Bool.not(String.is_empty(s))

def lines(s: String) -> List<&2, String>:
  List.filter(~String, ~nonempty, String.lines(s))

def has(xs: List<&2, String>, +value: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      String.eq(h, value) || has(t, value)

# JSON escaping differs from Bend's String.quote for control characters.
def quote_char(c: Char) -> String:
  match c:
    case Chr{+n}:
      choose(String, U32.is_eq(n, 34), "\\\"",
        choose(String, U32.is_eq(n, 92), "\\\\",
          choose(String, (n < 32 : U32), "\\u00" ++ String.drop(U32.hex((n + 256 : U32)), 1n), SCon{Chr{n}, SNil{}})))

def escape(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      quote_char(c) ++ escape(t)

def quote(s: String) -> String:
  "\"" ++ escape(s) ++ "\""

def array(xs: List<&2, String>) -> String:
  "[" ++ String.join(xs, ",") ++ "]"

def field(key: String, value: String) -> String:
  quote(key) ++ ":" ++ value

def object(fields: List<&2, String>) -> String:
  "{" ++ String.join(fields, ",") ++ "}"

def string_or_null(+value: String) -> String:
  choose(String, String.is_empty(value), "null", quote(value))

def json_bool(value: Bool) -> String:
  choose(String, value, "true", "false")

# jq supplies JSON decoding only. Publication decisions live in Bend.
def json_query(value: String, query: String) -> Task(String):
  output("jq", ["-cSer", query], value)

def json_text(value: String, key: String) -> Task(String):
  output("jq", ["-r", ".[" ++ quote(key) ++ "] // empty"], value)

def json_items(value: String) -> Task(List<&2, String>):
  do Task<List<&2, String>>:
    text : String <- output("jq", ["-c", ".[]"], value)
    return lines(text)

def real_directory(path: String) -> Task(String):
  output("sh", ["-c", "cd -- \"$1\" && pwd -P", "done", path], "")

def env_value(result: Result<&1, &1, U32 & String, String>) -> String:
  match result:
    case Done{value}:
      value
    case Fail{error}:
      ""

def env(name: String) -> Task(String):
  do IO<Result<&1, &1, String, String>>:
    result : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
    Task.pure(String, env_value(result))

def strings_json(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, Nil{}}:
      quote(h)
    case Con{h, t}:
      quote(h) ++ "," ++ strings_json(t)

type Entry is Data:
  Entry{key: String, value: String}

type Options is Data:
  Options{pairs: List<&2, Entry>}

def parse_options(args: List<String>, +allowed: List<&2, String>, pairs: List<&2, Entry>) -> Task(Options):
  match args:
    case Nil{}:
      Task.pure(Options, Options{List.reverse(&2, Entry, pairs)})
    case Con{+key, Con{value, tail}}:
      do Task<Options>:
        require(has(allowed, key), "unknown option: " ++ key)
        parse_options(tail, allowed, Entry{key, value} <> pairs)
    case _:
      Task.fail(Options, "expected an option followed by its value")

def option_values(pairs: List<&2, Entry>, +key: String) -> List<&2, String>:
  match pairs:
    case Nil{}:
      Nil{}
    case Con{Entry{name, value}, tail}:
      +rest = option_values(tail, key)
      choose(List<&2, String>, String.eq(name, key), value <> rest, rest)

def values(options: Options, key: String) -> List<&2, String>:
  Options{pairs} = options
  option_values(pairs, key)

def option(options: Options, key: String, fallback: String) -> String:
  +value = first(values(options, key))
  choose(String, nonempty(value), value, fallback)

def complete(result: Result<&1, &1, String, String>, code: U32) -> IO(Unit):
  match result:
    case Done{text}:
      IO.print(text)
    case Fail{message}:
      IO.die(Unit, code, message)
