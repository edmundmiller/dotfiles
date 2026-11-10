#ifndef HEY_PROCESS_SUPPORT
#define HEY_PROCESS_SUPPORT
#include <spawn.h>
#include <sys/wait.h>

extern char **environ;

static int hey_spawn_literal(pid_t *child, char **argv, posix_spawn_file_actions_t *actions, char **environment) {
  if (strchr(argv[0], '/')) return posix_spawn(child, argv[0], actions, NULL, argv, environment);
  const char *path = NULL;
  for (size_t i = 0; environment[i]; i++) {
    if (!strncmp(environment[i], "PATH=", 5)) path = environment[i] + 5;
  }
  if (!path) path = "/usr/bin:/bin";
  int saved = ENOENT;
  for (const char *part = path;;) {
    size_t length = strcspn(part, ":");
    size_t size = length + strlen(argv[0]) + 2;
    char *candidate = io_mem(malloc(size));
    if (length) snprintf(candidate, size, "%.*s/%s", (int)length, part, argv[0]);
    else snprintf(candidate, size, "%s", argv[0]);
    int error = posix_spawn(child, candidate, actions, NULL, argv, environment);
    free(candidate);
    if (error == EACCES) saved = EACCES;
    else if (error != ENOENT && error != ENOTDIR) return error;
    if (part[length] == 0) return saved;
    part += length + 1;
  }
}

#endif
