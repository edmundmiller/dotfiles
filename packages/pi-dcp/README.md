# Pi-DCP: Dynamic Context Pruning Extension

![Monolith logo](pi-dcp-banner.png)

Intelligently prunes conversation context to optimize token usage while preserving conversation coherence.

## Features

- **Deduplication**: Removes duplicate tool outputs based on content hash
- **Superseded Writes**: Removes older file writes when newer versions exist
- **Error Purging**: Removes resolved errors from context
- **Recency Protection**: Always preserves recent messages

## Installation

Clone the repository into your pi agent extensions directory:

```bash
git clone https://github.com/zenobi-us/pi-dcp.git ~/.pi/agent/extensions/pi-dcp
```

## Usage

The extension runs automatically on every LLM call. No manual intervention needed.

### Commands

- `/dcp-debug` - Toggle debug logging
- `/dcp-stats` - Show pruning statistics for current session
- `/dcp-toggle` - Enable/disable the extension
- `/dcp-recent <number>` - Set how many recent messages to always keep (default: 10)

### Flags

- `--dcp-enabled=true/false` - Enable/disable extension at startup
- `--dcp-debug=true/false` - Enable debug logging at startup

## Architecture

### Workflow

1. **Prepare Phase**: Rules annotate message metadata
2. **Process Phase**: Rules make pruning decisions based on metadata
3. **Filter Phase**: Messages marked for pruning are removed

### Built-in Rules

Located in `src/rules/`:

1. **Deduplication** (`deduplication.ts`)
   - Prepare: Hash message content
   - Process: Mark duplicates for pruning

2. **Superseded Writes** (`superseded-writes.ts`)
   - Prepare: Extract file paths from write/edit operations
   - Process: Mark older writes to the same file for pruning

3. **Error Purging** (`error-purging.ts`)
   - Prepare: Identify errors and check if resolved
   - Process: Mark resolved errors for pruning

4. **Recency** (`recency.ts`)
   - Process: Protect last N messages from pruning (overrides other rules)

### Configuration

Default configuration in `src/config.ts`:

```typescript
{
  enabled: true,
  debug: false,
  rules: ['deduplication', 'superseded-writes', 'error-purging', 'recency'],
  keepRecentCount: 10
}
```

## Custom Rules

Create custom pruning rules by implementing the `PruneRule` interface:

```typescript
import type { PruneRule } from "./src/types";

const myRule: PruneRule = {
  name: "my-custom-rule",
  description: "My custom pruning logic",

  prepare(msg, ctx) {
    // Annotate metadata during prepare phase
    msg.metadata.myScore = calculateScore(msg.message);
  },

  process(msg, ctx) {
    // Make pruning decision during process phase
    if (msg.metadata.myScore < threshold) {
      msg.metadata.shouldPrune = true;
      msg.metadata.pruneReason = "low score";
    }
  },
};
```

Then add to configuration: `rules: ['deduplication', myRule]`

## Development

### Type Checking

```bash
bun run typecheck
```

### Project Structure

```
pi-dcp/
├── index.ts              # Main extension entry point
├── package.json          # Bun package config
├── tsconfig.json         # TypeScript config
├── src/
│   ├── types.ts          # Core type definitions
│   ├── config.ts         # Configuration management
│   ├── metadata.ts       # Message metadata utilities
│   ├── registry.ts       # Rule registration system
│   ├── workflow.ts       # Prepare > Process > Filter workflow
│   └── rules/
│       ├── index.ts      # Export and register all rules
│       ├── deduplication.ts
│       ├── superseded-writes.ts
│       ├── error-purging.ts
│       └── recency.ts
└── README.md
```

## How It Works

1. **Context Event Hook**: The extension subscribes to the `context` event, which fires before each LLM call
2. **Message Processing**: All messages are wrapped with metadata containers
3. **Prepare Phase**: Each rule's `prepare` function annotates metadata (hashes, file paths, etc.)
4. **Process Phase**: Each rule's `process` function makes pruning decisions based on metadata
5. **Filter Phase**: Messages marked with `shouldPrune: true` are removed
6. **Result**: Pruned message list is returned to pi and sent to the LLM

## Benefits

- **Token Savings**: Removes redundant and obsolete messages
- **Cost Reduction**: Fewer tokens = lower API costs
- **Preserved Coherence**: Smart rules keep important context
- **Transparent**: No changes to user experience
- **Configurable**: Adjust rules and thresholds as needed
- **Extensible**: Easy to add custom rules

## Example Output

```
[pi-dcp] Initialized with 4 rules: deduplication, superseded-writes, error-purging, recency
[pi-dcp] Pruned 12 / 45 messages
[pi-dcp] Pruned 8 / 52 messages
```

With debug mode enabled (`/dcp-debug`):

```
[pi-dcp] Dedup: marking duplicate message at index 15 (hash: k2l9x)
[pi-dcp] SupersededWrites: found file operation at index 23: src/index.ts
[pi-dcp] SupersededWrites: marking superseded write at index 23: src/index.ts
[pi-dcp] ErrorPurging: found resolved error at index 31
[pi-dcp] Recency: protecting message at index 48 (distance from end: 3, threshold: 10)
[pi-dcp] Filter phase complete: 12 pruned, 33 kept (45 total)
[pi-dcp] Pruned messages:
  [15] assistant: duplicate content
  [23] toolResult: superseded by later write to src/index.ts
  [31] toolResult: error resolved by later success
  ...
```

## License

MIT
