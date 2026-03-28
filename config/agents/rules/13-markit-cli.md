---
purpose: Use the markit CLI to convert files and URLs to markdown.
---

# Markit CLI

Use `markit` when converting files, URLs, PDFs, Office docs, images, or audio into markdown.

In Pi, prefer the `markit` tool/package when available.

- `markit <source>` — convert to markdown
- `markit <source> -q` — raw markdown for piping
- `markit <source> --json` — structured output for parsing
- `markit <source> -o output.md` — write to a file
- `markit formats` — list supported inputs

Prefer it over ad-hoc extraction when the user wants markdown from a file or URL.
