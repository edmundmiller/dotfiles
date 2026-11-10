import Base

def defer_command(argv: List<String>) -> IO(U32):
  import "./resources.c"

def cancel_cleanup(token: U32) -> IO(Unit):
  import "./resources.c"

def finish_task(status: U32) -> IO(Unit):
  import "./resources.c"
