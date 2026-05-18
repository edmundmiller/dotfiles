# Updating the Simplify Skill

The prompt lives in variable `zY4` in Claude Code's minified JS bundle.

## Binary location

```
~/.local/share/claude/versions/<version>
```

## Extraction

```bash
python3 -c "
with open('<binary_path>', 'rb') as f:
    data = f.read()
marker = b'zY4=\`# Simplify'
idx = data.find(marker)
start = idx + 5  # skip 'zY4=\`'
end = data.find(b'\`});', start)
print(data[start:end].decode('utf-8', errors='replace'))
"
```

## Registration in the bundle

```js
Mz({
  name: "simplify",
  description: "Review changed code for reuse, quality, and efficiency, then fix any issues found.",
  userInvocable: true,
  async getPromptForCommand(T) {
    let _ = zY4;
    if (T) _ += `\n\n## Additional Focus\n\n${T}`;
    return [{ type: "text", text: _ }];
  },
});
```

## After extracting

1. Replace `${uA}` → `subagent tool`
2. Replace `${b$}` → `grep/search`
3. Unescape JS artifacts (`\`` → backtick, `\u2014`→`—`)
4. Diff against `SKILL.md` and update
