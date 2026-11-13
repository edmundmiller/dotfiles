# pi-thimble

A Pi-native TypeScript port of [Thimble](https://github.com/safety-research/thimble). Tools, inspector, record parsing, labels, coverage, and evidence validation run inside Pi. There is no Python bridge, external engine, or analysis server.

## Use

`/thimble` opens a native Pi inspector with Claims, Citations, Cards, Labels, and Coverage sections. Wide terminals show the selected item's evidence beside the list. Narrow terminals switch between list and details. The agent can call these tools:

- `thimble_card` displays a JSON file as a table or bar chart and keeps a snapshot in the active session branch. `/thimble cards` opens the cards and their complete rows.
- `thimble_cite` checks a claim against a local file line. Native code validates the evidence first. A separate call to the selected Pi model judges whether the surrounding passage supports the whole sentence. `/thimble citations` shows the verdicts, evidence, and usage. No automatic rewriting of the original answer occurs.
- `thimble_label` lists labels, reads records, or creates regex/model labels. Runs are limited to 100 records. `/thimble labels <name>` opens records and lets the human correct a label by its record reference. The agent cannot mark its own label as human-checked through this tool.
- `thimble_coverage` reports what successful Pi `read` and untruncated `bash` results on the active branch exposed. Partial reads count only the lines shown. `/thimble coverage` opens the report.

Other commands:

- `/thimble claims` lists saved claims and any exactly matching citation checks. `/thimble claims extract` explicitly extracts unverified claims from the last answer. Opening or navigating the inspector never triggers model requests.
- `/thimble rewrite shorter` rewrites the last answer in a separate view. Any style text works.
- `/thimble ask Why did it fail?` answers a side question using the last answer without adding the exchange to the main model context.

Model requests use Pi's selected model and provider authentication, including OAuth. They return usage but are not added to Pi's main-turn token counter. Loading the extension makes no model requests. Claims, rewrites, and side questions have no filesystem or shell tools. They cannot independently investigate a claim. No data is sent to a separate Thimble service.

## Inspector controls

Use **1–5** to switch sections, **↑/↓** to select an item, and **Enter** to inspect it. Cards and labels open their rows or records. **Tab** switches between list and details. In details, **↑/↓**, **PgUp/PgDn**, and **Home/End** scroll. **Esc** returns to the list or parent group; **q** closes the inspector. **r** reloads the current page.

Fullscreen Pi supports clicking section tabs and list entries, and scrolling details with the mouse wheel. Regular mode keeps the terminal's mouse behavior; all actions have a keyboard path. The layout adapts when the terminal resizes.

Select a label record and press **c** to correct it. Pi asks for an allowed value, or `-` to remove a check. Cancelling or entering an invalid value leaves the record unchanged. The inspector reopens on the same record after the dialog. A label page displays at most 100 records and reports how many it shows.

Citation details display the saved passage, verdict, deterministic validation, and recorded model usage. They do not reread the cited file or imply that a model verdict is proof. Coverage loads only when its section is opened. Source files remain untouched.

## Differences from upstream

This is not a drop-in Claude plugin or the browser workbench. Cards are declarative tables/bar charts, not arbitrary generated JavaScript. There are no clickable citations in the original answer, in-place answer edits, background claim extraction, claim dependency graphs, self-modifying fixes, or browser workbench. Citations are selectable inside the inspector. Side questions use a separate view rather than a persistent side conversation. Code-based labels are not exposed.

Coverage is conservative and incomplete. It omits Pi `grep`, `find`, `ls`, implicit context files, external/remote tools, and truncated Bash results. It is not a claim that the agent read everything. Coverage follows the active branch after rewinds and resumes. Cards, citations, and claims also follow the active branch. Labels belong to the Pi session and folder, and are shared between branches of that session, matching upstream's conversation-scoped label storage.

Text reads of PDF or binary bytes do not count as page or media views. Whole-image coverage requires an image block in the tool result. A notice-only read receives no content credit. Files that cannot be parsed remain explicitly uncountable in the coverage report; they do not prevent reporting valid files or count as established zero-record sources.

Cards and citation files must resolve inside Pi's current working folder. Label globs must be relative and cannot contain `..`. Label state lives in `~/.pi/agent/thimble`, separate from upstream's `~/.thimble`; `THIMBLE_PI_HOME` overrides it. Source records are never edited by the extension.

## Packaging and development

The Pi module links the built package at `~/.pi/agent/packages/pi-thimble`; shared settings select that package. A host rebuild is required to activate those links. Building or testing does not activate them.

For development, load this directory with Pi's `-e` flag. The extension uses Pi's Node.js runtime and native APIs. Neither a Python installation nor an upstream checkout is needed. `THIMBLE_ENGINE` and `THIMBLE_PYTHON` are no longer used.

Run `bun run typecheck` and `bun test` in this directory. All engine integration tests run unconditionally. Model-response tests use a simulated transport; no test makes a provider request.

The native engine adapts the exposed operations from upstream revision `258863f92d112677447df3df226df8e2013429fc`. It retains the previous Pi session/folder label layout and reads existing saved labels. Regex rules now use JavaScript Unicode regular expression syntax, not Python's `re` syntax. Invalid patterns fail without saving a label. Rules run in a worker with a five-second deadline so a pathological regex does not block the inspector.

Source reads have a 64 MiB budget, checked before and during reading; a SQLite database and its WAL share that budget. Parsing, PDF page estimation, and SQLite queries run in cancellable workers rather than Pi's UI thread. Counting, label sampling, and inspector record reads return only counts or selected records without transferring the entire parsed dataset to Pi. Workers have a 30-second deadline and an 8 MiB response budget; full-row responses also stop at 100,000 records. Node workers have a 256 MiB JavaScript heap limit, not a total-memory limit. Bun does not enforce that heap limit. Exceeding a budget fails that operation instead of continuing without a limit. Parsing may still materialize a budgeted source inside its worker.

This port is Apache-2.0 and includes upstream's license and attribution in `LICENSE` and `NOTICE`.
