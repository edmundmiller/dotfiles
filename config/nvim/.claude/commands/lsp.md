Configure LSP server, formatter, or linter for a language.

If the user provides a language or server name, configure the LSP in `lua/plugins/astrolsp.lua`.

## Your Task

1. **Parse the language/server reference**
   - Language name (e.g., "python", "rust", "typescript")
   - Server name (e.g., "pyright", "rust_analyzer", "tsserver")
   - Specific configuration request (e.g., "enable inlay hints", "use clippy")

2. **Invoke the nvim:lsp-config skill** to handle implementation
   - The skill will research server settings if needed
   - Configure the LSP server in astrolsp.lua
   - Ensure Mason installation
   - Add language-specific keybindings if requested
   - Document external dependencies

3. **Provide setup guidance**
   - Explain the configuration changes
   - Note external tool requirements (e.g., clippy, eslint)
   - Suggest testing with `:LspInfo` and `:Mason`
   - Mention relevant community language packs

## Examples

**Command**: `/nvim:lsp python with pyright`
**Action**: Configure pyright with type checking, ensure Mason installation

**Command**: `/nvim:lsp rust_analyzer with clippy`
**Action**: Configure rust_analyzer to use clippy for check-on-save

**Command**: `/nvim:lsp typescript inlay hints`
**Action**: Enable TypeScript inlay hints for parameters and types

**Command**: `/nvim:lsp go`
**Action**: Set up gopls with common configuration, mention pack.go from AstroCommunity

## Notes

- Check .claude/CONTEXT.md for common LSP patterns
- Verify if language pack exists in AstroCommunity (includes LSP)
- Use nvim-lspconfig server names (e.g., `lua_ls` not `lua-language-server`)
- Always mention Mason installation
- Note external dependencies (clippy, rustup, npm packages, etc.)
- Suggest `:LspInfo` for verification
