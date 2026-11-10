#ifndef HEY_PROCESS_EFFECTS
#define HEY_PROCESS_EFFECTS
#include <poll.h>
#include "process-support.h"
#include "utf8-support.h"

static void hey_process_append(char **data, size_t *length, const char *chunk, size_t size) {
  *data = io_mem(realloc(*data, *length + size + 1));
  memcpy(*data + *length, chunk, size);
  *length += size;
  (*data)[*length] = 0;
}

static Term hey_process_run_impl(Env e, Term *f, IoWork *w, char **environment, const char *source) {
  size_t count = 0, capacity = 8;
  char **argv = io_mem(calloc(capacity, sizeof(char *)));
  Term xs = f[0];
  while (term_aux(xs) == CID(Con)) {
    Term pair[2];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, pair));
    u64 size = 0;
    char *arg = io_cstr(e, pair[0], &size);
    if (io_nul(arg, size)) {
      fputs("hey: invalid subprocess argument\n", stderr);
      exit(126);
    }
    if (count + 1 >= capacity) {
      capacity *= 2;
      argv = io_mem(realloc(argv, capacity * sizeof(char *)));
    }
    argv[count++] = arg;
    xs = pair[1];
  }
  argv[count] = NULL;
  if (count == 0) {
    fputs("hey: subprocess needs an executable\n", stderr);
    exit(126);
  }
  bool capture = term_aux(f[1]) == CID(True);
  int pipes[2][2] = {{-1, -1}, {-1, -1}};
  posix_spawn_file_actions_t actions;
  int error = posix_spawn_file_actions_init(&actions);
  bool initialized = error == 0;
  bool input_error = false;
  int input = -1;
  if (error == 0 && source) {
    input = open(source, O_RDONLY);
    if (input < 0) error = errno;
    if (error == 0 && input < 3) {
      int moved = fcntl(input, F_DUPFD, 3);
      if (moved < 0) error = errno;
      close(input);
      input = moved;
    }
    if (error == 0 && fcntl(input, F_SETFD, FD_CLOEXEC)) error = errno;
    if (error == 0) error = posix_spawn_file_actions_adddup2(&actions, input, STDIN_FILENO);
    if (error == 0) error = posix_spawn_file_actions_addclose(&actions, input);
    input_error = error != 0;
  }
  if (error == 0 && capture) {
    for (int i = 0; i < 2 && error == 0; i++) {
      if (pipe(pipes[i]) != 0) { error = errno; break; }
      for (int j = 0; j < 2 && error == 0; j++) {
        if (pipes[i][j] < 3) {
          int moved = fcntl(pipes[i][j], F_DUPFD, 3);
          if (moved < 0) { error = errno; break; }
          close(pipes[i][j]);
          pipes[i][j] = moved;
        }
        if (fcntl(pipes[i][j], F_SETFD, FD_CLOEXEC)) error = errno;
      }
      if (error) break;
      error = posix_spawn_file_actions_adddup2(&actions, pipes[i][1], i + 1);
      if (error == 0) error = posix_spawn_file_actions_addclose(&actions, pipes[i][0]);
      if (error == 0) error = posix_spawn_file_actions_addclose(&actions, pipes[i][1]);
    }
  }
  pid_t child = -1;
  if (error == 0) error = hey_spawn_literal(&child, argv, &actions, environment);
  if (initialized) posix_spawn_file_actions_destroy(&actions);
  if (input >= 0) close(input);
  for (int i = 0; i < 2; i++) {
    if (pipes[i][1] >= 0) close(pipes[i][1]);
  }
  char *out[2] = {NULL, NULL};
  size_t lengths[2] = {0, 0};
  if (error == 0 && capture) {
    struct pollfd watched[2] = {{pipes[0][0], POLLIN, 0}, {pipes[1][0], POLLIN, 0}};
    while (watched[0].fd >= 0 || watched[1].fd >= 0) {
      int ready = poll(watched, 2, -1);
      if (ready < 0 && errno == EINTR) continue;
      if (ready < 0) { error = errno; break; }
      for (int i = 0; i < 2; i++) {
        if (!watched[i].revents) continue;
        char buffer[8192];
        ssize_t size = read(watched[i].fd, buffer, sizeof(buffer));
        if (size > 0) hey_process_append(&out[i], &lengths[i], buffer, size);
        else if (size == 0 || errno != EINTR) {
          close(watched[i].fd);
          watched[i].fd = -1;
          pipes[i][0] = -1;
        }
      }
    }
  }
  for (int i = 0; i < 2; i++) if (pipes[i][0] >= 0) close(pipes[i][0]);
  int status = 0;
  if (child >= 0) {
    while (waitpid(child, &status, 0) < 0) {
      if (errno != EINTR) { error = errno; break; }
    }
  }
  unsigned code = error ? (error == ENOENT && !input_error ? 127 : 126)
    : WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
  if (error) {
    char message[1024];
    int length = input_error
      ? snprintf(message, sizeof(message), "hey: cannot read subprocess input: %s\n", strerror(error))
      : snprintf(message, sizeof(message), "hey: cannot run %s: %s\n", argv[0], strerror(error));
    if (capture) hey_process_append(&out[1], &lengths[1], message, length < (int)sizeof(message) ? length : sizeof(message) - 1);
    else fputs(message, stderr);
  }
  for (size_t i = 0; i < count; i++) free(argv[i]);
  free(argv);
  if (!hey_valid_utf8_bytes(out[0], lengths[0])) {
    const char *message = "hey: subprocess stdout is not valid UTF-8\n";
    hey_process_append(&out[1], &lengths[1], message, strlen(message));
    lengths[0] = 0;
    if (!code) code = 126;
  }
  Term fields[3] = {(Term)code, io_str(e, out[0] ? out[0] : "", lengths[0]), io_str(e, out[1] ? out[1] : "", lengths[1])};
  free(out[0]);
  free(out[1]);
  u64 location = heap_alloc(e, cls_fit(3));
  for (size_t i = 0; i < 3; i++) e.mem[location + i] = io_seal(e, fields[i], CID(ProcessResult));
  return term_ctr(CID(ProcessResult), location);
}

#ifdef CID(run)
static Term hey_process_run(Env e, Term *f, IoWork *w) {
  return hey_process_run_impl(e, f, w, environ, NULL);
}
#endif

static Term hey_process_environment_impl(Env e, Term *f, IoWork *w, bool set_value) {
  u64 name_length, value_length = 0;
  char *name = io_cstr(e, f[2], &name_length);
  char *value = set_value ? io_cstr(e, f[3], &value_length) : NULL;
  if (!name_length || io_nul(name, name_length) || strchr(name, '=') || (value && io_nul(value, value_length))) {
    fputs("hey: invalid subprocess environment override\n", stderr);
    exit(126);
  }
  size_t count = 0;
  while (environ[count]) count++;
  char **environment = io_mem(calloc(count + 2, sizeof(char *)));
  size_t next = 0;
  for (size_t i = 0; i < count; i++) {
    if (strncmp(environ[i], name, name_length) || environ[i][name_length] != '=') environment[next++] = environ[i];
  }
  char *entry = NULL;
  if (set_value) {
    entry = io_mem(malloc(name_length + value_length + 2));
    snprintf(entry, name_length + value_length + 2, "%s=%s", name, value);
    environment[next++] = entry;
  }
  Term result = hey_process_run_impl(e, f, w, environment, NULL);
  free(entry);
  free(environment);
  free(name);
  free(value);
  return result;
}

#ifdef CID(run_with_environment)
static Term hey_process_run_with_environment(Env e, Term *f, IoWork *w) {
  return hey_process_environment_impl(e, f, w, true);
}
#endif

#ifdef CID(run_without_environment)
static Term hey_process_run_without_environment(Env e, Term *f, IoWork *w) {
  return hey_process_environment_impl(e, f, w, false);
}
#endif

#ifdef CID(run_with_input)
static Term hey_process_run_with_input(Env e, Term *f, IoWork *w) {
  u64 length;
  char *source = io_cstr(e, f[2], &length);
  if (io_nul(source, length)) {
    fputs("hey: invalid subprocess input path\n", stderr);
    exit(126);
  }
  Term result = hey_process_run_impl(e, f, w, environ, source);
  free(source);
  return result;
}
#endif

static void __attribute__((constructor)) hey_process_use(void) {
#ifdef CID(run)
  io_eff(CID(run), hey_process_run);
#endif
#ifdef CID(run_with_environment)
  io_eff(CID(run_with_environment), hey_process_run_with_environment);
#endif
#ifdef CID(run_without_environment)
  io_eff(CID(run_without_environment), hey_process_run_without_environment);
#endif
#ifdef CID(run_with_input)
  io_eff(CID(run_with_input), hey_process_run_with_input);
#endif
}
#endif
