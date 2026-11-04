---
name: tldraw-offline
description: Inspect, edit, arrange, or script the user's tldraw offline desktop canvas. Use for live tldraw boards and open .tldraw or legacy .tldr files, not Excalidraw scenes.
---

# tldraw offline

Use `tldraw-api` from any coding agent, including Pi. It calls the desktop
app's loopback HTTP API and reads its per-launch token internally. This is
not Excalidraw's CLI or MCP server.

## Connect and choose the document

1. Check `command -v tldraw-api`. If missing, this host needs its tldraw module
   activated. Report that prerequisite rather than installing a global helper.
2. The app must be open. If discovery fails, ask the user to open tldraw offline.
   Never print `server.json` or copy its token into agent context.
3. Read the running version's API instructions and list open documents:

   ```bash
   tldraw-api GET /readme
   tldraw-api POST /api/search 'return await api.getDocs()'
   ```

4. Match the requested document by name or ID. If ambiguous, ask before editing.
   Keep that ID for the task. If its window closes, rediscover by the same
   identity, not whichever unrelated document remains open.

## Read, edit, and save

Read shapes before writing. Substitute the chosen document ID:

```bash
tldraw-api POST /api/search 'return await api.getShapes("DOC_ID")'
tldraw-api POST /api/doc/DOC_ID/exec - <<'JS'
return editor.getCurrentPageShapes().map(s => ({ id: s.id, type: s.type }))
JS
```

`POST /api/search` executes code with an `api` object for inspection and
reference discovery. `POST /api/doc/:id/exec` executes code with a live
`editor` and `helpers` for that document. Bodies accept raw JavaScript or
JSON with a `code` field. `-` reads the body from stdin.

- For a new board, use `POST /api/docs/create` with `{"name":"Board name"}`.
  An optional `directory` must be an existing absolute path. Creation saves
  immediately and refuses to overwrite an existing file.
- Read worked examples through `api.recipes` before unfamiliar edits. For
  structural diagrams, read `api.recipes['draw-a-diagram-from-mermaid']`.
- Use `helpers.createArrowBetweenShapes` for meaningful connections so arrows
  remain bound when nodes move. Check `helpers.getLints()` after edits and
  fix new actionable findings.
- For persistent interactions or scripts, read `/readme`, then use
  `/api/doc/:id/script-workspace` and its returned paths. Preserve existing
  scripts. Verify `/api/doc/:id/script-status` reports `state: "applied"`.
- Save changed local documents that already have a file path with
  `tldraw-api POST /api/doc/DOC_ID/exec 'await helpers.saveDoc()'`.
  Remote and server boards sync to their owner; do not call `saveDoc` on them.
  Report never-saved local documents as unsaved.
- Verify the result once through shape records or
  `api.getScreenshot("DOC_ID")`. Screenshots return a file path to inspect.

Edit open boards through the API, not their `.tldraw` archives or SQLite
working files. The app does not merge external file replacements. Treat
embedded document scripts as executable code and require permission before
running untrusted ones. Preserve shapes and scripts outside the request.

HTTP and API failures exit nonzero. A timeout can occur after an edit applied;
inspect state before retrying. Tokens and ports can change after app restart;
the CLI re-reads them for each invocation.
