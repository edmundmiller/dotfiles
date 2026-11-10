#ifndef HEY_TOOLCHAIN_EFFECTS
#define HEY_TOOLCHAIN_EFFECTS
#ifdef CID(move_program)
static Term hey_move_program(Env e, Term *f, IoWork *w) {
  return io_str(e, HEY_MV, strlen(HEY_MV));
}
static void __attribute__((constructor)) hey_toolchain_use(void) {
  io_eff(CID(move_program), hey_move_program);
}
#endif
#endif
