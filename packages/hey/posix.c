#ifndef HEY_POSIX_EFFECTS
#define HEY_POSIX_EFFECTS
#include <sys/stat.h>
#include <sys/random.h>
#include <sys/utsname.h>
#include <dirent.h>
#include <sys/file.h>
#include <pwd.h>
#include "utf8-support.h"
#ifdef __APPLE__
#include <mach/mach.h>
#include <sys/sysctl.h>
#else
#include <sys/sysinfo.h>
#endif

static char *hey_posix_string(Env e, Term value) {
  u64 size;
  char *text = io_cstr(e, value, &size);
  if (io_nul(text, size)) {
    fputs("hey: NUL in filesystem or environment argument\n", stderr);
    exit(126);
  }
  return text;
}

static void hey_posix_failure(const char *operation, const char *path) {
  fprintf(stderr, "hey: %s %s: %s\n", operation, path, strerror(errno));
  exit(1);
}

static Term hey_posix_text(Env e, const char *text, size_t size, const char *description) {
  if (!hey_valid_utf8_bytes(text, size)) {
    fprintf(stderr, "hey: %s is not valid UTF-8\n", description);
    exit(2);
  }
  return io_str(e, text, size);
}

#ifdef CID(process_alive)
static Term hey_process_alive(Env e, Term *f, IoWork *w) {
  int result = kill((pid_t)(u32)f[0], 0);
  return term_pak(result == 0 || errno == EPERM ? CID(True) : CID(False), 0);
}
#endif

#ifdef CID(process_id)
static Term hey_process_id(Env e, Term *f, IoWork *w) {
  return (Term)(u32)getpid();
}
#endif

#ifdef CID(random_uuid)
static Term hey_random_uuid(Env e, Term *f, IoWork *w) {
  unsigned char bytes[16];
  if (getentropy(bytes, sizeof(bytes))) hey_posix_failure("getentropy", "");
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  char uuid[37];
  snprintf(uuid, sizeof(uuid), "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
    bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
    bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
  return io_str(e, uuid, 36);
}
#endif

#ifdef CID(temporary_directory)
static Term hey_temporary_directory(Env e, Term *f, IoWork *w) {
  const char *base = getenv("TMPDIR");
  if (!base || !base[0]) base = "/tmp";
  if (!hey_valid_utf8(base)) {
    fputs("hey: TMPDIR is not valid UTF-8\n", stderr);
    exit(2);
  }
  size_t size = strlen(base) + 24;
  char *path = io_mem(malloc(size));
  snprintf(path, size, "%s/hey.XXXXXX", base);
  if (!mkdtemp(path)) hey_posix_failure("mkdtemp", path);
  Term result = io_str(e, path, strlen(path));
  free(path);
  return result;
}
#endif

#if defined(CID(path_identity)) || defined(CID(rename_if_unchanged))
static int hey_stat_identity(const char *path, char identity[128]) {
  struct stat info;
  if (stat(path, &info)) return errno;
#ifdef __APPLE__
  struct timespec changed = info.st_ctimespec;
#else
  struct timespec changed = info.st_ctim;
#endif
  snprintf(identity, 128, "%llu:%llu:%lld:%ld", (unsigned long long)info.st_dev,
    (unsigned long long)info.st_ino, (long long)changed.tv_sec, changed.tv_nsec);
  return 0;
}
#endif

#ifdef CID(path_identity)
static Term hey_path_identity(Env e, Term *f, IoWork *w) {
  char *path = hey_posix_string(e, f[0]);
  char identity[128] = "";
  int error = hey_stat_identity(path, identity);
  if (error && error != ENOENT) { errno = error; hey_posix_failure("stat identity", path); }
  free(path);
  return io_str(e, identity, strlen(identity));
}
#endif

#ifdef CID(rename_if_unchanged)
static Term hey_rename_if_unchanged(Env e, Term *f, IoWork *w) {
  char *path = hey_posix_string(e, f[0]);
  char *destination = hey_posix_string(e, f[1]);
  char *expected = hey_posix_string(e, f[2]);
  size_t size = strlen(path) + 16;
  char *coordination = io_mem(malloc(size));
  snprintf(coordination, size, "%s.reclaim", path);
  int fd = open(coordination, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
  if (fd < 0) hey_posix_failure("open coordination lock", coordination);
  while (flock(fd, LOCK_EX)) {
    if (errno != EINTR) hey_posix_failure("acquire coordination lock", coordination);
  }
  char identity[128] = "";
  int error = hey_stat_identity(path, identity);
  bool renamed = false;
  if (!error && expected[0] && !strcmp(expected, identity)) {
    if (!rename(path, destination)) renamed = true;
    else error = errno;
  }
  flock(fd, LOCK_UN);
  close(fd);
  if (error && error != ENOENT) { errno = error; hey_posix_failure("rename unchanged directory", path); }
  free(path);
  free(destination);
  free(expected);
  free(coordination);
  return term_pak(renamed ? CID(True) : CID(False), 0);
}
#endif

static Term hey_directory_names(Env e, Term *f, bool directories_only, u64 nil, u64 con) {
  char *path = hey_posix_string(e, f[0]);
  DIR *directory = opendir(path);
  if (!directory && errno != ENOENT) hey_posix_failure("opendir", path);
  Term names = term_pak(nil, 0);
  if (directory) {
    struct dirent *entry;
    errno = 0;
    while ((entry = readdir(directory))) {
      if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
      bool include = !directories_only;
      if (directories_only) {
        struct stat info;
        int status = fstatat(dirfd(directory), entry->d_name, &info, AT_SYMLINK_NOFOLLOW);
        if (status && errno != ENOENT) hey_posix_failure("stat directory entry", path);
        include = !status && S_ISDIR(info.st_mode);
      }
      if (include) names = io_node(e, con, hey_posix_text(e, entry->d_name, strlen(entry->d_name), "directory entry"), names);
      errno = 0;
    }
    if (errno) hey_posix_failure("readdir", path);
    if (closedir(directory)) hey_posix_failure("closedir", path);
  }
  free(path);
  return names;
}

#ifdef CID(list_directories)
static Term hey_list_directories(Env e, Term *f, IoWork *w) {
  return hey_directory_names(e, f, true, CID(Nil), CID(Con));
}
#endif

#ifdef CID(list_entries)
static Term hey_list_entries(Env e, Term *f, IoWork *w) {
  return hey_directory_names(e, f, false, CID(Nil), CID(Con));
}
#endif

#ifdef CID(system_memory)
static Term hey_system_memory(Env e, Term *f, IoWork *w) {
  uint64_t total = 0, available = 0, swap_total = 0, swap_used = 0;
  unsigned pressure = 0;
#ifdef __APPLE__
  size_t size = sizeof(total);
  sysctlbyname("hw.memsize", &total, &size, NULL, 0);
  vm_size_t page_size = 0;
  vm_statistics64_data_t memory;
  mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
  host_t host = mach_host_self();
  if (host_page_size(host, &page_size) == KERN_SUCCESS &&
      host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&memory, &count) == KERN_SUCCESS) {
    available = ((uint64_t)memory.free_count + memory.inactive_count) * page_size;
  }
  mach_port_deallocate(mach_task_self(), host);
  struct xsw_usage swap;
  size = sizeof(swap);
  if (!sysctlbyname("vm.swapusage", &swap, &size, NULL, 0)) {
    swap_total = swap.xsu_total;
    swap_used = swap.xsu_used;
  }
  size = sizeof(pressure);
  sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &size, NULL, 0);
#else
  struct sysinfo memory;
  if (!sysinfo(&memory)) {
    total = (uint64_t)memory.totalram * memory.mem_unit;
    available = ((uint64_t)memory.freeram + memory.bufferram) * memory.mem_unit;
    swap_total = (uint64_t)memory.totalswap * memory.mem_unit;
    swap_used = (uint64_t)(memory.totalswap - memory.freeswap) * memory.mem_unit;
  }
  FILE *meminfo = fopen("/proc/meminfo", "r");
  if (meminfo) {
    char line[256];
    unsigned long long kib;
    while (fgets(line, sizeof(line), meminfo)) {
      if (sscanf(line, "MemAvailable: %llu kB", &kib) == 1) available = (uint64_t)kib * 1024;
    }
    fclose(meminfo);
  }
#endif
  Term fields[5] = {(u32)(total >> 20), (u32)(available >> 20), (u32)(swap_total >> 20), (u32)(swap_used >> 20), pressure};
  u64 location = heap_alloc(e, cls_fit(5));
  for (size_t i = 0; i < 5; i++) e.mem[location + i] = fields[i];
  return term_ctr(CID(SystemMemory), location);
}
#endif

#ifdef CID(stdin_terminal)
static Term hey_stdin_terminal(Env e, Term *f, IoWork *w) {
  return term_pak(isatty(STDIN_FILENO) ? CID(True) : CID(False), 0);
}
#endif

#ifdef CID(path_executable)
static Term hey_path_executable(Env e, Term *f, IoWork *w) {
  char *path = hey_posix_string(e, f[0]);
  bool executable = access(path, X_OK) == 0;
  free(path);
  return term_pak(executable ? CID(True) : CID(False), 0);
}
#endif

static bool hey_command_file(const char *path) {
  struct stat info;
  return stat(path, &info) == 0 && S_ISREG(info.st_mode) && access(path, X_OK) == 0;
}

static char *hey_command_path(const char *program) {
  if (strchr(program, '/')) return hey_command_file(program) ? io_mem(strdup(program)) : NULL;
  if (program[0]) {
    const char *path = getenv("PATH");
    if (!path) path = "/usr/bin:/bin";
    for (const char *part = path;;) {
      size_t length = strcspn(part, ":");
      size_t size = length + strlen(program) + 2;
      char *candidate = io_mem(malloc(size));
      if (length) snprintf(candidate, size, "%.*s/%s", (int)length, part, program);
      else snprintf(candidate, size, "%s", program);
      if (hey_command_file(candidate)) return candidate;
      free(candidate);
      if (!part[length]) break;
      part += length + 1;
    }
  }
  return NULL;
}

#ifdef CID(command_exists)
static Term hey_command_exists(Env e, Term *f, IoWork *w) {
  char *program = hey_posix_string(e, f[0]);
  char *path = hey_command_path(program);
  bool found = path != NULL;
  free(path);
  free(program);
  return term_pak(found ? CID(True) : CID(False), 0);
}
#endif

#ifdef CID(find_command)
static Term hey_find_command(Env e, Term *f, IoWork *w) {
  char *program = hey_posix_string(e, f[0]);
  char *path = hey_command_path(program);
  Term result = path ? io_box(e, CID(Some), hey_posix_text(e, path, strlen(path), "command path")) : term_pak(CID(None), 0);
  free(path);
  free(program);
  return result;
}
#endif

#ifdef CID(read_line)
static Term hey_read_line(Env e, Term *f, IoWork *w) {
  u64 prompt_size;
  char *prompt = io_cstr(e, f[0], &prompt_size);
  io_out(stdout, prompt, prompt_size);
  free(prompt);
  fflush(stdout);
  char *line = NULL;
  size_t capacity = 0;
  ssize_t size = getline(&line, &capacity, stdin);
  if (size < 0) {
    if (feof(stdin)) errno = EPIPE;
    hey_posix_failure("read input", "");
  }
  if (size && line[size - 1] == '\n') size--;
  if (size && line[size - 1] == '\r') size--;
  Term result = hey_posix_text(e, line, size, "input line");
  free(line);
  return result;
}
#endif

#ifdef CID(platform_name)
static Term hey_platform_name(Env e, Term *f, IoWork *w) {
  struct utsname info;
  if (uname(&info)) hey_posix_failure("uname", "");
  return io_str(e, info.sysname, strlen(info.sysname));
}
#endif

#ifdef CID(host_name)
static Term hey_host_name(Env e, Term *f, IoWork *w) {
  char name[256];
  if (gethostname(name, sizeof(name))) hey_posix_failure("gethostname", "");
  name[sizeof(name) - 1] = 0;
  char *dot = strchr(name, '.');
  if (dot) *dot = 0;
  return hey_posix_text(e, name, strlen(name), "host name");
}
#endif

#ifdef CID(current_directory)
static Term hey_current_directory(Env e, Term *f, IoWork *w) {
  char *path = getcwd(NULL, 0);
  if (!path) hey_posix_failure("getcwd", "");
  Term result = hey_posix_text(e, path, strlen(path), "current directory");
  free(path);
  return result;
}
#endif

#ifdef CID(change_directory)
static Term hey_change_directory(Env e, Term *f, IoWork *w) {
  char *path = hey_posix_string(e, f[0]);
  if (chdir(path)) hey_posix_failure("chdir", path);
  free(path);
  return term_pak(CID(Unit), 0);
}
#endif

#ifdef CID(absolute_path)
static char *hey_normalize_absolute(const char *path) {
  size_t length = strlen(path), used = 1, depth = 0;
  char *result = io_mem(malloc(length + 2));
  size_t *offsets = io_mem(malloc((length + 1) * sizeof(size_t)));
  result[0] = '/';
  for (const char *cursor = path; *cursor;) {
    if (*cursor == '/') { cursor++; continue; }
    size_t size = strcspn(cursor, "/");
    if (size == 2 && !memcmp(cursor, "..", 2)) {
      if (depth) used = offsets[--depth];
    } else if (!(size == 1 && *cursor == '.')) {
      offsets[depth++] = used;
      if (used > 1) result[used++] = '/';
      memcpy(result + used, cursor, size);
      used += size;
    }
    cursor += size;
  }
  result[used] = 0;
  free(offsets);
  return result;
}

static Term hey_absolute_path(Env e, Term *f, IoWork *w) {
  char *input = hey_posix_string(e, f[0]);
  char *expanded = input;
  if (input[0] == '~') {
    size_t name_size = strcspn(input + 1, "/");
    char *name = io_mem(strndup(input + 1, name_size));
    struct passwd *account = name_size ? getpwnam(name) : NULL;
    const char *home = name_size ? (account ? account->pw_dir : NULL) : getenv("HOME");
    if (!home || !*home) hey_posix_failure("expand home directory", name);
    if (!hey_valid_utf8(home)) { fputs("hey: home directory is not valid UTF-8\n", stderr); exit(2); }
    size_t size = strlen(home) + strlen(input + name_size + 1) + 1;
    expanded = io_mem(malloc(size));
    snprintf(expanded, size, "%s%s", home, input + name_size + 1);
    free(name);
  }
  char *absolute = expanded;
  if (expanded[0] != '/') {
    char *cwd = getcwd(NULL, 0);
    if (!cwd) hey_posix_failure("getcwd", "");
    if (!hey_valid_utf8(cwd)) { fputs("hey: current directory is not valid UTF-8\n", stderr); exit(2); }
    size_t size = strlen(cwd) + strlen(expanded) + 2;
    absolute = io_mem(malloc(size));
    snprintf(absolute, size, "%s/%s", cwd, expanded);
    free(cwd);
  }
  char *prefix = io_mem(strdup(absolute));
  char *resolved;
  while (!(resolved = realpath(prefix, NULL))) {
    if (errno != ENOENT && errno != ENOTDIR) hey_posix_failure("realpath", prefix);
    char *slash = strrchr(prefix, '/');
    if (!slash) hey_posix_failure("absolute path", prefix);
    if (slash == prefix) prefix[1] = 0;
    else *slash = 0;
  }
  size_t size = strlen(resolved) + strlen(absolute + strlen(prefix)) + 2;
  char *joined = io_mem(malloc(size));
  snprintf(joined, size, "%s/%s", resolved, absolute + strlen(prefix));
  char *normalized = hey_normalize_absolute(joined);
  Term result = hey_posix_text(e, normalized, strlen(normalized), "absolute path");
  free(normalized); free(joined); free(resolved); free(prefix);
  if (absolute != expanded) free(absolute);
  if (expanded != input) free(expanded);
  free(input);
  return result;
}
#endif

#ifdef CID(path_exists)
static Term hey_path_exists(Env e, Term *f, IoWork *w) {
  char *path = hey_posix_string(e, f[0]);
  struct stat info;
  int result = stat(path, &info);
  free(path);
  return term_pak(result == 0 ? CID(True) : CID(False), 0);
}
#endif

#ifdef CID(set_environment)
static Term hey_set_environment(Env e, Term *f, IoWork *w) {
  char *name = hey_posix_string(e, f[0]);
  char *value = hey_posix_string(e, f[1]);
  if (setenv(name, value, 1)) hey_posix_failure("setenv", name);
  free(name);
  free(value);
  return term_pak(CID(Unit), 0);
}
#endif

#ifdef CID(read_text)
static Term hey_read_text(Env e, Term *f, IoWork *w) {
  char *path = hey_posix_string(e, f[0]);
  FILE *file = fopen(path, "rb");
  if (!file) hey_posix_failure("read", path);
  char *data = NULL;
  size_t length = 0;
  char buffer[8192];
  size_t size;
  while ((size = fread(buffer, 1, sizeof(buffer), file)) > 0) {
    data = io_mem(realloc(data, length + size));
    memcpy(data + length, buffer, size);
    length += size;
  }
  if (ferror(file)) hey_posix_failure("read", path);
  if (fclose(file)) hey_posix_failure("close", path);
  Term result = hey_posix_text(e, data ? data : "", length, "file contents");
  free(path);
  free(data);
  return result;
}
#endif

#ifdef CID(write_text)
static Term hey_write_text(Env e, Term *f, IoWork *w) {
  char *path = hey_posix_string(e, f[0]);
  u64 length;
  char *data = io_cstr(e, f[1], &length);
  FILE *file = fopen(path, "wb");
  if (!file) hey_posix_failure("write", path);
  if (fwrite(data, 1, length, file) != length) hey_posix_failure("write", path);
  if (fclose(file)) hey_posix_failure("close", path);
  free(path);
  free(data);
  return term_pak(CID(Unit), 0);
}
#endif

static void __attribute__((constructor)) hey_posix_use(void) {
#ifdef CID(process_alive)
  io_eff(CID(process_alive), hey_process_alive);
#endif
#ifdef CID(process_id)
  io_eff(CID(process_id), hey_process_id);
#endif
#ifdef CID(random_uuid)
  io_eff(CID(random_uuid), hey_random_uuid);
#endif
#ifdef CID(temporary_directory)
  io_eff(CID(temporary_directory), hey_temporary_directory);
#endif
#ifdef CID(path_identity)
  io_eff(CID(path_identity), hey_path_identity);
#endif
#ifdef CID(rename_if_unchanged)
  io_eff(CID(rename_if_unchanged), hey_rename_if_unchanged);
#endif
#ifdef CID(list_directories)
  io_eff(CID(list_directories), hey_list_directories);
#endif
#ifdef CID(list_entries)
  io_eff(CID(list_entries), hey_list_entries);
#endif
#ifdef CID(system_memory)
  io_eff(CID(system_memory), hey_system_memory);
#endif
#ifdef CID(stdin_terminal)
  io_eff(CID(stdin_terminal), hey_stdin_terminal);
#endif
#ifdef CID(path_executable)
  io_eff(CID(path_executable), hey_path_executable);
#endif
#ifdef CID(command_exists)
  io_eff(CID(command_exists), hey_command_exists);
#endif
#ifdef CID(find_command)
  io_eff(CID(find_command), hey_find_command);
#endif
#ifdef CID(read_line)
  io_eff(CID(read_line), hey_read_line);
#endif
#ifdef CID(platform_name)
  io_eff(CID(platform_name), hey_platform_name);
#endif
#ifdef CID(host_name)
  io_eff(CID(host_name), hey_host_name);
#endif
#ifdef CID(current_directory)
  io_eff(CID(current_directory), hey_current_directory);
#endif
#ifdef CID(change_directory)
  io_eff(CID(change_directory), hey_change_directory);
#endif
#ifdef CID(absolute_path)
  io_eff(CID(absolute_path), hey_absolute_path);
#endif
#ifdef CID(path_exists)
  io_eff(CID(path_exists), hey_path_exists);
#endif
#ifdef CID(set_environment)
  io_eff(CID(set_environment), hey_set_environment);
#endif
#ifdef CID(read_text)
  io_eff(CID(read_text), hey_read_text);
#endif
#ifdef CID(write_text)
  io_eff(CID(write_text), hey_write_text);
#endif
}
#endif
