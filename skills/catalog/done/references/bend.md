# Bend helpers

Run `bend guide` before changing these helpers. Keep decision rules in
`../LAWS.bend` and their proofs in `../PROOF.bend`. Run `bend PROOF.bend`
from the skill directory before committing; `bend PROOF.bend --verdict`
also checks the pure laws with BendTT. A changed law needs review as a changed
contract, not as a way to make a failing proof pass.

The laws cover retry and required-gate decisions in `scripts/policy.bend`.
They do not prove Git, GitHub, jq, shell utilities, the Bend runtime, or the
filesystem correct. Test those boundaries against disposable repositories.

The entrypoints retain their arguments and JSON field names. Invoke them as
`bend scripts/<name>.bend -- ...`, or compile with
`bend scripts/<name>.bend -o <binary>`. Native compilation needs clang 14+.
The `--` separator prevents Bend from consuming the helper's options.
GNU coreutils provides `sha256sum`, `readlink`, `realpath`, `env`, `mktemp`, and `rm`, including
on macOS. Bash supplies pipe failure handling when hashing symlink targets.
No helper installs dependencies or changes host configuration.

jj snapshots use a temporary Git index seeded from the recorded working-copy
commit to fingerprint current tracked and untracked files. They require jj's
Git backend and leave its operation log, working-copy state, and Git index
unchanged. Untracked nested repositories retain the directory-entry fingerprint
used by the old helper; their contents are not recursively verified.

`common.bend` runs literal subprocess argument lists. jq decodes JSON and
selects API records; shell snippets only resolve directories and hash symlink
targets. Commands have a two-minute timeout and a combined 64 MiB output
limit. Exceeding either limit fails the operation. After a push, an uncertain
process result must be reconciled against the remote before another write.

Independent diff reads, hashes, and GitHub requests use `IO.fork` and
`IO.join`. Compile natively to execute subprocesses concurrently. Bend's JS
backend blocks on subprocesses. Replay, fetch/reset, push, and teardown stay
sequential because each changes state the next step reads.

From the dotfiles root, with Bend, clang, Git, jq, Bash, coreutils, and jj on PATH:

```bash
bend skills/catalog/done/PROOF.bend
python3 -B -m unittest tests.test_done_closeout tests.test_done_skill
```

The tests compile native entrypoints into a disposable directory. Set
`DONE_SKILL_DIR` to test a copied bundle. Retain the entire skill directory,
including the laws and imported Bend modules, when publishing it.
