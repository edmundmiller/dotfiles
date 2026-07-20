---
purpose: Quick command reference for the supported agent jj workflow.
applies_to: Isolated agent workspaces in existing jj repositories.
entrypoint: hey agent-start --repo "$PWD" --workspace <path> --task <id>.
verification: jj status, jj workspace list, and the done verifier.
update_when: Supported agent jj commands or safety boundaries change.
---

# jj agent quick reference

## Start

```bash
hey agent-start --repo "$PWD" --workspace <path> --base 'trunk()' --task <id>
```

## Inspect

```bash
jj status
jj diff
jj log -r '@-::@ | trunk()'
jj obslog -r @
jj workspace list
```

## Shape changes

```bash
jj describe -m "type: intent"
jj new
jj split       # supervised interactive use only
jj squash -r <source> -t <target>
jj rebase -s <source> -d <destination>
```

## Read without moving `@`

```bash
jj diff -r <revision>
jj file show -r <revision> <path>
jj log -r <revision>
```

## Recover

```bash
jj restore <path>
jj op log
jj op show <operation>
```

Coordinate before `jj undo` or `jj op restore`; the operation log is shared across workspaces.

## Finish

Use `done`. Do not run raw `git push` or `jj_vcs align_push` in jj repositories. The verifier requires task containment plus equality of local, tracked-remote, and authoritative remote bookmark tips before cleanup.
