# Updating the Batch Skill

The prompt is returned by function `wY4(T)` in Claude Code's minified JS bundle.
Worker instructions live in variable `PY4` (lazy-initialized in block `G0A`).

## Binary location

```
~/.local/share/claude/versions/<version>
```

## Extraction

```bash
python3 -c "
with open('<binary_path>', 'rb') as f:
    data = f.read()
marker = b'# Batch: Parallel Work Orchestration'
idx = data.find(marker)
# scan back for opening backtick
start = idx
for i in range(idx-1, max(idx-100, 0), -1):
    if data[i:i+1] == b'\x60':
        start = i + 1
        break
# find closing backtick
pos = idx + len(marker)
while pos < len(data):
    if data[pos:pos+1] == b'\x60' and data[pos-1:pos] != b'\\\\':
        break
    pos += 1
print(data[start:pos].decode('utf-8', errors='replace'))
"
```

Worker instructions (PY4):

```bash
python3 -c "
with open('<binary_path>', 'rb') as f:
    data = f.read()
idx = data.find(b'var G0A=W(()=>{')
print(data[idx:idx+1000].decode('utf-8', errors='replace'))
"
```

## Registration in the bundle

```js
Mz({
  name: "batch",
  description:
    "Research and plan a large-scale change, then execute it in parallel across 5\u201330 isolated worktree agents that each open a PR.",
  whenToUse:
    "Use when the user wants to make a sweeping, mechanical change across many files (migrations, refactors, bulk renames) that can be decomposed into independent parallel units.",
  argumentHint: "<instruction>",
  userInvocable: true,
  disableModelInvocation: true,
  async getPromptForCommand(T) {
    let _ = T.trim();
    if (!_) return [{ type: "text", text: YY4 }]; // no-arg help
    if (!(await Qh())) return [{ type: "text", text: JY4 }]; // not a git repo
    return [{ type: "text", text: wY4(_) }]; // full prompt
  },
});
```

## Template variables

| Variable | Value               | Used in        |
| -------- | ------------------- | -------------- |
| `${T}`   | user instruction    | wY4 (runtime)  |
| `${TGT}` | `EnterPlanMode`     | Phase 1 intro  |
| `${GI}`  | `ExitPlanMode`      | Phase 1 step 5 |
| `${kf}`  | `AskUserQuestion`   | Phase 1 step 3 |
| `${uA}`  | `Agent`             | Phase 2        |
| `${Hz}`  | `Skill`             | PY4 step 1     |
| `${j0A}` | `5`                 | Phase 1 step 2 |
| `${W0A}` | `30`                | Phase 1 step 2 |
| `${PY4}` | worker instructions | Phase 2 block  |

## After extracting

1. Replace all template variables per table above
2. Inline `PY4` worker instructions into Phase 2 code block
3. Unescape JS artifacts (`\`` → backtick, `\u2014`→`—`, `\u2013`→`–`)
4. Diff against `SKILL.md` and update
