# pi-scurl

Secure web fetch pi extension. Registers `web_fetch` tool.

## Structure

```
packages/pi-scurl/
├── index.ts              # Extension entry, registers web_fetch tool + custom rendering
├── src/
│   ├── fetch.ts          # secureFetch(): HTTP → mdream markdown, secret scan, injection detect
│   ├── secrets.ts        # 25+ regex patterns for API keys/tokens (AWS, GitHub, Stripe, etc.)
│   └── injection.ts      # 7-category prompt injection regex detection, redaction, wrapping
└── tests/                # bun:test — `bun test` from this dir
```

## Key Facts

- **HTML→Markdown**: Uses `mdream` npm package (not CLI). Imports `htmlToMarkdown` + `withMinimalPreset`.
- **No Python deps**: Everything is pure TS. No scurl binary needed.
- **Secret scanning**: Runs on outgoing URL + headers. Blocks request if secret detected. Skips `Authorization` header.
- **Injection detection**: Pattern-only (no ML). Weighted composite score across 7 categories. Threshold default 0.3.
- **Truncation**: Uses pi's `truncateHead` (50KB / 2000 lines).
- **Package reference**: Listed in `config/pi/settings.jsonc` as `"~/.config/dotfiles/packages/pi-scurl"`.
- **Dep install**: Nix activation in `modules/agents/pi/default.nix` runs `bun install` if `node_modules/` missing.

## Adding Secret Patterns

Edit `src/secrets.ts` — add to `SECRET_PATTERNS` array. Each entry: `{ name, pattern: RegExp, description }`.

## Adding Injection Categories

Edit `src/injection.ts` — add to `PATTERN_CATEGORIES` record. Update `codeMap` for short signal name. Optionally adjust `weights`.
