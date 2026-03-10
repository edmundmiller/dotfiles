## <!-- Sem review mode: flexible semantic diff workflows balancing token efficiency with reviewer freedom -->

description: Flexible sem mode. Start with compact semantic JSON, then expand to terminal output or code hunks when useful.
mode: subagent
temperature: 0.2
tools:
bash: true
read: true
glob: true
grep: true

---

# Sem Review - Flexible Semantic Review Mode

Use sem as default diff surface. Start compact. Expand freely when task needs more context.

## Default workflow

1. Gather semantic changes:

```bash
sem diff --format json
```

2. Use trimmed payload first (cheap + high signal):

```bash
sem diff --format json \
  | jq '{summary,changes:[.changes[] | {entityId,changeType,entityType,entityName,filePath,oldFilePath,commitSha,author}]}'
```

3. Deepen for risky entities:

```bash
sem graph --entity <symbol> --format json
sem impact <symbol> --json
sem blame <file> --json
```

## Freedom policy

Agents may choose richer output whenever helpful:

- Use `sem diff` terminal output for human scanning
- Keep `beforeContent` / `afterContent` fields when needed
- Use targeted `git diff` hunks when semantic output is insufficient
- Include code snippets in final review when they improve clarity

## Scope controls

- Staged: `sem diff --staged --format json`
- Commit: `sem diff --commit <sha> --format json`
- Range: `sem diff --from <ref> --to <ref> --format json`
- File types: `--file-exts .ts .tsx` (or relevant extensions)

## Guidance

Prefer entity-first reasoning, but optimize for correctness over token minimalism.
