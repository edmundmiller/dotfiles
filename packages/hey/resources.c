#ifndef HEY_RESOURCE_EFFECTS
#define HEY_RESOURCE_EFFECTS
#include "process-support.h"

typedef struct HeyCleanup {
  struct HeyCleanup *next;
  u32 token;
  char **argv;
} HeyCleanup;

static HeyCleanup *hey_cleanups;
static u32 hey_cleanup_next_token;
static bool hey_cleanup_registered;

static void hey_cleanup_free(HeyCleanup *entry) {
  for (size_t i = 0; entry->argv[i]; i++) free(entry->argv[i]);
  free(entry->argv);
  free(entry);
}

static unsigned hey_cleanup_run(void) {
  HeyCleanup *entry = hey_cleanups;
  hey_cleanups = NULL;
  unsigned first_failure = 0;
  while (entry) {
    pid_t child;
    int error = hey_spawn_literal(&child, entry->argv, NULL, environ);
    int status = 0;
    if (!error) {
      while (waitpid(child, &status, 0) < 0) {
        if (errno != EINTR) { error = errno; break; }
      }
    }
    unsigned code = error ? (error == ENOENT ? 127 : 126)
      : WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
    if (code) {
      fprintf(stderr, "hey: cleanup command %s failed with status %u\n", entry->argv[0], code);
      if (!first_failure) first_failure = code;
    }
    HeyCleanup *next = entry->next;
    hey_cleanup_free(entry);
    entry = next;
  }
  return first_failure;
}

static void hey_cleanup_at_exit(void) {
  hey_cleanup_run();
}

#ifdef CID(defer_command)
static Term hey_defer_command(Env e, Term *f, IoWork *w) {
  size_t count = 0, capacity = 8;
  char **argv = io_mem(calloc(capacity, sizeof(char *)));
  Term xs = f[0];
  while (term_aux(xs) == CID(Con)) {
    Term pair[2];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, pair));
    u64 length;
    char *arg = io_cstr(e, pair[0], &length);
    if (io_nul(arg, length)) {
      fputs("hey: invalid cleanup argument\n", stderr);
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
  if (!count || !argv[0][0] || hey_cleanup_next_token == UINT32_MAX) {
    fputs("hey: invalid cleanup registration\n", stderr);
    exit(126);
  }
  if (!hey_cleanup_registered) {
    if (atexit(hey_cleanup_at_exit)) {
      fputs("hey: could not register resource cleanup\n", stderr);
      exit(126);
    }
    hey_cleanup_registered = true;
  }
  HeyCleanup *entry = io_mem(malloc(sizeof(*entry)));
  entry->token = ++hey_cleanup_next_token;
  entry->argv = argv;
  entry->next = hey_cleanups;
  hey_cleanups = entry;
  return (Term)entry->token;
}
#endif

#ifdef CID(cancel_cleanup)
static Term hey_cancel_cleanup(Env e, Term *f, IoWork *w) {
  HeyCleanup **entry = &hey_cleanups;
  while (*entry) {
    if ((*entry)->token == (u32)f[0]) {
      HeyCleanup *removed = *entry;
      *entry = removed->next;
      hey_cleanup_free(removed);
      break;
    }
    entry = &(*entry)->next;
  }
  return term_pak(CID(Unit), 0);
}
#endif

#ifdef CID(finish_task)
static Term hey_finish_task(Env e, Term *f, IoWork *w) {
  unsigned cleanup_status = hey_cleanup_run();
  exit(f[0] ? (u32)f[0] : cleanup_status);
}
#endif

static void __attribute__((constructor)) hey_resources_use(void) {
#ifdef CID(defer_command)
  io_eff(CID(defer_command), hey_defer_command);
#endif
#ifdef CID(cancel_cleanup)
  io_eff(CID(cancel_cleanup), hey_cancel_cleanup);
#endif
#ifdef CID(finish_task)
  io_eff(CID(finish_task), hey_finish_task);
#endif
}
#endif
