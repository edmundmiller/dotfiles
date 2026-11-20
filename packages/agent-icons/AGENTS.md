# Agent icons

Monochrome SVGs build an OTF font for Ghostty's `font-codepoint-map`. Keep
`default.nix` and Ghostty's mapping aligned:
U+F5000 Claude, U+F5001 Amp, U+F5002 OpenCode, U+F5003 Anthropic.

Claude/Anthropic assets come from Simple Icons (CC0); Amp from its press kit,
OpenCode from its brand kit. Preserve attribution/licensing when adding assets.

Run `hey check packages/agent-icons` after SVG, codepoint, or packaging changes.
Also inspect the generated font mapping in Ghostty;
a successful font build does not prove those consumers use the same codepoint.
