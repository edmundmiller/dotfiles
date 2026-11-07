# Simplify provenance

`references/simplify.md` adapts Claude Code's bundled `/simplify` prompt. Installed versions
live under `~/.local/share/claude/versions/`. Search the selected binary for the
Simplify heading/registration; minified variable names such as historical `zY4`
are version-specific, not a stable extraction interface.

When refreshing, decode JavaScript escapes and replace tool interpolation with
portable descriptions (historically `${uA}` → subagent tool, `${b$}` → search).
Verify those substitutions against the selected version before updating the guide.

Record the selected Claude version or commit in the change, then run
the quality validator at `skills/catalog/skill-quality/scripts/validate.py` on
`skills/catalog/deslop`. Historical minified identifiers do not prove that a
new bundle exposes the same tool placeholders.
