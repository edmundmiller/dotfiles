# agent-icons

Custom font mapping AI agent logos to Private Use Area codepoints for use in Ghostty via `font-codepoint-map`.

## Icon Sources

| Agent     | Source                                                                   | License |
| --------- | ------------------------------------------------------------------------ | ------- |
| Claude    | [Simple Icons](https://icon-sets.iconify.design/simple-icons/claude/)    | CC0 1.0 |
| Anthropic | [Simple Icons](https://icon-sets.iconify.design/simple-icons/anthropic/) | CC0 1.0 |
| Amp       | [ampcode.com/press-kit](https://ampcode.com/press-kit) — mark-light.svg  | —       |
| OpenCode  | [opencode.ai/brand](https://opencode.ai/brand) — logo-dark.svg           | —       |

## Architecture

1. SVGs live in `svgs/` (monochrome, single-color fill)
2. `default.nix` builds an OTF font via fontforge/fantasticon mapping each to a PUA codepoint
3. Ghostty `font-codepoint-map` renders just those codepoints from this font
4. `tmux-smart-name` DISPLAY_NAMES references the PUA codepoints

## Codepoint Map

```
U+F5000 = claude
U+F5001 = anthropic
U+F5002 = amp
U+F5003 = opencode
```

## Adding a New Icon

1. Add monochrome SVG to `svgs/<name>.svg` (single path, no fills — fill comes from terminal fg color)
2. Add codepoint mapping in `default.nix`
3. Update `tmux-smart-name` DISPLAY_NAMES
4. `hey rebuild`
