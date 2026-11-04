---
name: excalidraw-cli
description: Create, inspect, update, and locally render Excalidraw scenes with the Excalidraw CLI. Use when a task needs an editable diagram or an Excalidraw+ workspace scene.
compatibility: portable
---

# Excalidraw CLI

Use `excalidraw` for editable diagrams. The managed binary is pinned at
`@excalidraw/cli@0.2.0`; inspect its current interface with
`excalidraw --help` or the relevant subcommand's `--help` before using an
unfamiliar option.

## Local diagrams

Treat a local `.excalidraw` file as the source of truth. Render it locally for
review without credentials:

```bash
excalidraw render architecture.excalidraw --out architecture.png
```

Use `--scale`, `--theme`, `--transparent`, or `--frame-id` only when the
requested output needs them. The CLI needs an installed Chrome, Chromium, Edge,
or Firefox; pass `--browser-path` or set `EXCALIDRAW_BROWSER_PATH` if automatic
detection fails. Images in a scene must be embedded, not linked by URL.

Inspect the rendered PNG before reporting a visual result. Keep local diagrams
and previews in the repository's appropriate documentation or artifact path;
do not overwrite an existing diagram without authorization.

## Excalidraw+ workspace

Workspace reads and writes require an API key. Prefer the injected
`EXCALIDRAW_API_KEY` environment variable; never request, print, or put a key
in source control. `excalidraw login` writes a user-local credential and is an
interactive alternative when the user explicitly authorizes it.

Read-only discovery is safe after credentials are available:

```bash
excalidraw whoami
excalidraw collections list
excalidraw scenes list --limit 20
excalidraw scenes content get <scene-id> --out scene.excalidraw
```

Creating, renaming, moving, pinning, trashing, or replacing workspace scenes is
an external write. Confirm the target workspace, collection, scene, and intended
content with the user before those operations. `scenes content put` replaces a
scene wholesale; use `scenes content patch` only when the user has authorized a
precise partial update. Render a workspace scene for review with:

```bash
excalidraw scenes render <scene-id> --out scene.png
```

The CLI emits JSON by default. Preserve parseable stdout in scripts and use
stderr for progress or errors. Use `-o table` only for human-readable list
output.
