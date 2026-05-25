# @jordyvd/pi-image-attachments

A distributable Pi extension package that brings image attachment behavior to Pi without any external runtime dependency beyond Pi itself.

## Features

- `Ctrl+V` clipboard images attach as draft images instead of leaving temp-file paths in the editor.
- Dragging or pasting a local image path into the editor attaches it.
- Draft images are shown as `[Image #N]` placeholders.
- Placeholders are stripped from the submitted text; only the image content is sent.
- Drafts containing only image placeholders are sent as image-only user messages.
- Screenshot tool results that save to `filePath` are promoted into inline image content so the agent can inspect them agentically.
- The extension nudges Pi to prefer inline screenshots when the agent needs to inspect the image itself.

## Install

From npm (recommended):

```bash
pi install npm:@jordyvd/pi-image-attachments
```

From source:

```bash
git clone https://github.com/jordyvandomselaar/pi-image-attachments.git
pi install ./pi-image-attachments
```

Try without installing:

```bash
pi -e npm:@jordyvd/pi-image-attachments
```

You can also point Pi at a local checkout while developing the extension.

## Package structure

This package uses Pi's `pi.extensions` manifest in `package.json`, so Pi can load it from npm, git, or a local path.

## Tests

```bash
bun test
bun test --coverage --coverage-reporter=text --coverage-reporter=lcov
```
