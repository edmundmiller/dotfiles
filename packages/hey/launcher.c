// Synchronous Bend 2.0.40 embedding for dispatch and native tasks.
// Do not start its event loop, install signal handlers, or parse RTS options.
#define main bend_runtime_main
#include "generated.c"
#undef main

#ifndef HEY_STACK_BASE_WORDS
#define HEY_STACK_BASE_WORDS 4096
#endif

int main(int argc, char** argv) {
  io_argc = argc;
  io_argv = argv;

  // Keep the runtime's CPU layout and growable allocator, but start at
  // 512 MiB virtual space instead of 8 GiB. Most of this layout is untouched.
  io_gpu = false;
  pool_size = 1;
  KEEP_WORDS = CAP_WORDS;
  u64 size = 1ull << 29;
  CORPUS = corpus_map(size);
  corpus_lay(CORPUS, size);
  memcpy(CORPUS + STAT_OFF, STAT_IMG, STAT_LEN * sizeof(u64));
  a32_store(a32_at(CORPUS, H_BUMP), 1);

  // List.append uses two evaluation words per argument. Leave room for the
  // main/IO frames and compiler changes, followed by a guard page. Unlike
  // pool_stack(), this changes neither signal dispositions nor the altstack.
  u64 stack_size = (((u64)argc * 8 + HEY_STACK_BASE_WORDS) * sizeof(Term) + 16383) & ~16383ull;
  io_stk = pool_mmap(stack_size + 16384);
  if (mprotect((char*)io_stk + stack_size, 16384, PROT_NONE)) {
    perror("hey: stack guard");
    return 126;
  }

  Env e = { CORPUS, ALC[0] };
  io_spawn(corpus_eval(CORPUS, term_tsk(MAIN_FID,
    task_node(e, MAIN_FID, TERM_HOLE, 0, 0))));
  while (io_runs != NULL) {
    io_step(e, io_pop(&io_runs));
  }
  return 126; // A successful exec or IO.exit never returns.
}
