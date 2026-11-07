import Base

# Arguments are bytes, not decoded Unicode: Unix filenames need not be UTF-8.
# The leading help spelling is special; all remaining arguments are opaque.
def is_help(arg: List<&2, U32>) -> Bool:
  match arg:
    case Nil{}:
      True{}
    case [104, 101, 108, 112]: # help
      True{}
    case [45, 104]: # -h
      True{}
    case [45, 45, 104, 101, 108, 112]: # --help
      True{}
    case _:
      False{}

def dispatch(help: Bool, args: List<List<&2, U32>>) -> List<List<&2, U32>>:
  match help args:
    case True{} Nil{}:
      [[116, 97, 115, 107, 115]] # tasks
    case True{} Con{first, Nil{}}:
      [[116, 97, 115, 107, 115]]
    case True{} Con{first, rest}:
      [114, 117, 110] <> List.append(&1, List<&2, U32>, rest, [[45, 45, 104, 101, 108, 112]])
    case False{} rest:
      [114, 117, 110] <> rest # run

def arguments(args: List<List<&2, U32>>) -> List<List<&2, U32>>:
  match args:
    case Nil{}:
      dispatch(True{}, Nil{})
    case Con{+first, rest}:
      dispatch(is_help(first), first <> rest)
