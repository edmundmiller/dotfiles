import Base
import ./dispatch.bend as Dispatch

# Only these pure argument-routing claims are proved. Exec, mise, tasks and
# host operations remain outside the proof and require integration tests.
law no_arguments_lists_tasks:
  {Dispatch.arguments(Nil{}) == [[116, 97, 115, 107, 115]] : List<List<&2, U32>>}

law help_spellings:
  {Dispatch.is_help([104, 101, 108, 112]) == True{} : Bool}

law short_help_spelling:
  {Dispatch.is_help([45, 104]) == True{} : Bool}

law long_help_spelling:
  {Dispatch.is_help([45, 45, 104, 101, 108, 112]) == True{} : Bool}

law empty_first_argument_is_help:
  {Dispatch.is_help(Nil{}) == True{} : Bool}

law run_preserves_arguments:
  for args: List<List<&2, U32>>
  {Dispatch.dispatch(False{}, args) == [114, 117, 110] <> args : List<List<&2, U32>>}

law task_help_preserves_tail:
  for first: List<&2, U32>
  for task: List<&2, U32>
  for rest: List<List<&2, U32>>
  {Dispatch.dispatch(True{}, first <> task <> rest) == [114, 117, 110] <> List.append(&1, List<&2, U32>, task <> rest, [[45, 45, 104, 101, 108, 112]]) : List<List<&2, U32>>}
