import Base
import ./LAWS.bend as Laws

def Laws.no_arguments_lists_tasks():
  {==}

def Laws.help_spellings():
  {==}

def Laws.short_help_spelling():
  {==}

def Laws.long_help_spelling():
  {==}

def Laws.empty_first_argument_is_help():
  {==}

def Laws.run_preserves_arguments(args):
  match args:
    case Nil{}:
      {==}
    case Con{first, rest}:
      {==}

def Laws.task_help_preserves_tail(first, task, rest):
  {==}
