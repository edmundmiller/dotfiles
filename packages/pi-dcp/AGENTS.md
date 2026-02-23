# Pi-DCP: Dynamic Context Pruning Extension

Pi port of [opencode-dcp](https://github.com/Opencode-DCP/opencode-dynamic-context-pruning). Prunes conversation context to reduce token usage while preserving coherence.

## Architecture

Extension hooks into pi's `context` event (fires before each LLM call). Workflow: prepare → process → filter.

**Rules** (`src/rules/`): deduplication, superseded-writes, error-purging, recency, tool-pairing
**Tools** (`src/tools/`): prune, distill, compress — LLM-callable context management
**Events** (`src/events/`): context hook that orchestrates the workflow

## Key Constraints

- **Thinking blocks**: `hasThinkingBlocks()` in `src/events/context.ts` guards against modifying assistant messages containing `thinking` or `redacted_thinking` blocks. API rejects modifications to these.
- **Tool pairing**: `tool-pairing` rule ensures toolCall/toolResult pairs stay intact — orphaned results cause API errors.
- **Recency protection**: Last N messages always preserved regardless of other rules.

## Related Upstream Bugs

Bug 2 (redacted_thinking) is in **pi-ai**, not pi-dcp:

- `~/.bun/install/global/node_modules/@mariozechner/pi-ai/dist/providers/anthropic.js`
- Streaming handler drops `redacted_thinking` blocks (never stored)
- `convertMessages` also lacks serialization for `redacted_thinking`
- Tracked: `dotfiles-pepc`, `dotfiles-0927`
