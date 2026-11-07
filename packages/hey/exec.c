// Compiled inside Bend 2.0.40's generated C. Keep this boundary version-pinned.
static Term hey_exec(Env e, Term* f, IoWork* w) {
  size_t count = 1, capacity = 8;
  char** args = io_mem(calloc(capacity, sizeof(char*)));
  args[0] = HEY_MISE;
  Term xs = f[0];
  while (term_aux(xs) == CID(Con)) {
    Term pair[2];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, pair));
    u64 size = 0;
    char* arg = io_cbuf(e, pair[0], &size, CID(Con));
    if (arg == NULL || io_nul(arg, size)) {
      fputs("hey: invalid argument bytes\n", stderr);
      exit(126);
    }
    if (count + 1 >= capacity) {
      capacity *= 2;
      args = io_mem(realloc(args, capacity * sizeof(char*)));
    }
    args[count++] = arg;
    xs = pair[1];
  }
  args[count] = NULL;
  // Both Nix and development builds embed one absolute executable path.
  execv(HEY_MISE, args);
  int error = errno;
  fprintf(stderr, "hey: cannot execute %s: %s\n", args[0], strerror(error));
  exit(error == ENOENT ? 127 : 126);
}

static void __attribute__((constructor)) hey_exec_use(void) {
  io_eff(CID(exec), hey_exec);
}
