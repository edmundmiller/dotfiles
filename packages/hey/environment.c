#ifndef HEY_ENVIRONMENT_EFFECTS
#define HEY_ENVIRONMENT_EFFECTS
#include "utf8-support.h"

#ifdef CID(environment_value)
static Term hey_environment_value(Env e, Term *f, IoWork *w) {
  u64 length;
  char *name = io_cstr(e, f[0], &length);
  const char *value = io_nul(name, length) || strchr(name, '=') ? NULL : getenv(name);
  if (value && !hey_valid_utf8(value)) {
    fprintf(stderr, "hey: environment variable %s is not valid UTF-8\n", name);
    exit(2);
  }
  Term result = value ? io_box(e, CID(Some), io_str(e, value, strlen(value))) : term_pak(CID(None), 0);
  free(name);
  return result;
}
#endif

#ifdef CID(validate_task_arguments)
static Term hey_validate_task_arguments(Env e, Term *f, IoWork *w) {
  for (int i = 1; i < io_argc; i++) {
    if (!hey_valid_utf8(io_argv[i])) {
      fprintf(stderr, "hey: task argument %d is not valid UTF-8\n", i);
      exit(2);
    }
  }
  return term_pak(CID(Unit), 0);
}
#endif

static void __attribute__((constructor)) hey_environment_use(void) {
#ifdef CID(environment_value)
  io_eff(CID(environment_value), hey_environment_value);
#endif
#ifdef CID(validate_task_arguments)
  io_eff(CID(validate_task_arguments), hey_validate_task_arguments);
#endif
}
#endif
