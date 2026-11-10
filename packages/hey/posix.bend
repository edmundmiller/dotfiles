import Base

type SystemMemory is Data:
  SystemMemory{total_mib: U32, available_mib: U32, swap_total_mib: U32, swap_used_mib: U32, pressure_level: U32}

def system_memory() -> IO(SystemMemory):
  import "./posix.c"

def process_alive(pid: U32) -> IO(Bool):
  import "./posix.c"

def process_id() -> IO(U32):
  import "./posix.c"

def temporary_directory() -> IO(String):
  import "./posix.c"

def random_uuid() -> IO(String):
  import "./posix.c"

def path_identity(path: String) -> IO(String):
  import "./posix.c"

def rename_if_unchanged(path: String, destination: String, identity: String) -> IO(Bool):
  import "./posix.c"

def list_directories(path: String) -> IO(List<&2, String>):
  import "./posix.c"

def list_entries(path: String) -> IO(List<&2, String>):
  import "./posix.c"

def stdin_terminal() -> IO(Bool):
  import "./posix.c"

def path_executable(path: String) -> IO(Bool):
  import "./posix.c"

def command_exists(program: String) -> IO(Bool):
  import "./posix.c"

def find_command(program: String) -> IO(Maybe<&2, String>):
  import "./posix.c"

def read_line(prompt: String) -> IO(String):
  import "./posix.c"

def platform_name() -> IO(String):
  import "./posix.c"

def host_name() -> IO(String):
  import "./posix.c"

def current_directory() -> IO(String):
  import "./posix.c"

def change_directory(path: String) -> IO(Unit):
  import "./posix.c"

def absolute_path(path: String) -> IO(String):
  import "./posix.c"

def path_exists(path: String) -> IO(Bool):
  import "./posix.c"

def set_environment(name: String, value: String) -> IO(Unit):
  import "./posix.c"

def read_text(path: String) -> IO(String):
  import "./posix.c"

def write_text(path: String, text: String) -> IO(Unit):
  import "./posix.c"
