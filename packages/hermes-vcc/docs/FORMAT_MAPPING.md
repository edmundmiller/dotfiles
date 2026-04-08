# Format Mapping: OpenAI Chat to VCC Anthropic JSONL

Complete field-level mapping between the OpenAI chat format used by Hermes and the Anthropic JSONL records expected by VCC.

## Core Field Mapping

### System Message

| OpenAI Field       | VCC JSONL Field    | Notes          |
| ------------------ | ------------------ | -------------- |
| `role: "system"`   | `type: "system"`   | Direct mapping |
| `content` (string) | `content` (string) | Direct mapping |

**Input:**

```json
{ "role": "system", "content": "You are a helpful assistant." }
```

**Output:**

```json
{ "type": "system", "content": "You are a helpful assistant." }
```

### User Message (plain text)

| OpenAI Field       | VCC JSONL Field            | Notes                  |
| ------------------ | -------------------------- | ---------------------- |
| `role: "user"`     | `type: "user"`             | Direct mapping         |
| `content` (string) | `message.content` (string) | Nested under `message` |

**Input:**

```json
{ "role": "user", "content": "What is VCC?" }
```

**Output:**

```json
{ "type": "user", "message": { "content": "What is VCC?" } }
```

### Assistant Message (text only)

| OpenAI Field        | VCC JSONL Field                    | Notes                                  |
| ------------------- | ---------------------------------- | -------------------------------------- |
| `role: "assistant"` | `type: "assistant"`                | Direct mapping                         |
| `content` (string)  | `message.content` (list of blocks) | Content becomes a list of typed blocks |
| --                  | `message.id` (string)              | Synthetic `msg_` + 24-char hex UUID    |

**Input:**

```json
{ "role": "assistant", "content": "VCC is the Virtual Context Compiler." }
```

**Output:**

```json
{
  "type": "assistant",
  "message": {
    "content": [{ "type": "text", "text": "VCC is the Virtual Context Compiler." }],
    "id": "msg_a1b2c3d4e5f6a1b2c3d4e5f6"
  }
}
```

### Assistant Message (with tool calls)

| OpenAI Field                                    | VCC JSONL Field                  | Notes                           |
| ----------------------------------------------- | -------------------------------- | ------------------------------- |
| `tool_calls[].id`                               | `message.content[].id`           | Direct mapping                  |
| `tool_calls[].function.name`                    | `message.content[].name`         | Direct mapping                  |
| `tool_calls[].function.arguments` (JSON string) | `message.content[].input` (dict) | Parsed from JSON string to dict |

When an assistant message has both text content and tool calls, they appear in the same `message.content` list: text blocks first, then tool_use blocks.

**Input:**

```json
{
  "role": "assistant",
  "content": "Let me check that file.",
  "tool_calls": [
    {
      "id": "call_abc123",
      "type": "function",
      "function": {
        "name": "read_file",
        "arguments": "{\"path\": \"/etc/hosts\"}"
      }
    }
  ]
}
```

**Output:**

```json
{
  "type": "assistant",
  "message": {
    "content": [
      { "type": "text", "text": "Let me check that file." },
      {
        "type": "tool_use",
        "name": "read_file",
        "id": "call_abc123",
        "input": { "path": "/etc/hosts" }
      }
    ],
    "id": "msg_a1b2c3d4e5f6a1b2c3d4e5f6"
  }
}
```

### Tool Result Message

| OpenAI Field          | VCC JSONL Field                       | Notes                                     |
| --------------------- | ------------------------------------- | ----------------------------------------- |
| `role: "tool"`        | `type: "user"`                        | Tool results are wrapped as user messages |
| `content` (string)    | `message.content[0].content` (string) | Nested inside a `tool_result` block       |
| `tool_call_id`        | `message.content[0].tool_use_id`      | Renamed field                             |
| `is_error` (optional) | `message.content[0].is_error` (bool)  | Auto-detected if not explicit             |

**Input:**

```json
{
  "role": "tool",
  "content": "127.0.0.1 localhost\n::1 localhost",
  "tool_call_id": "call_abc123"
}
```

**Output:**

```json
{
  "type": "user",
  "message": {
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "call_abc123",
        "content": "127.0.0.1 localhost\n::1 localhost"
      }
    ]
  }
}
```

## Edge Cases

### Thinking Blocks

`<think>` and `<REASONING_SCRATCHPAD>` tags in assistant content are extracted into separate `thinking` blocks placed before any text blocks.

**Input:**

```json
{
  "role": "assistant",
  "content": "<think>The user wants to understand VCC.</think>VCC stands for Virtual Context Compiler."
}
```

**Output:**

```json
{
  "type": "assistant",
  "message": {
    "content": [
      { "type": "thinking", "thinking": "The user wants to understand VCC." },
      { "type": "text", "text": "VCC stands for Virtual Context Compiler." }
    ],
    "id": "msg_a1b2c3d4e5f6a1b2c3d4e5f6"
  }
}
```

`<REASONING_SCRATCHPAD>` blocks are converted to the same `thinking` type and are extracted first (before `<think>` blocks).

### Multiple Tool Calls

A single assistant message can contain multiple tool calls. Each becomes a separate `tool_use` block in the content list.

**Input:**

```json
{
  "role": "assistant",
  "content": null,
  "tool_calls": [
    {
      "id": "call_1",
      "type": "function",
      "function": { "name": "read_file", "arguments": "{\"path\": \"a.py\"}" }
    },
    {
      "id": "call_2",
      "type": "function",
      "function": { "name": "read_file", "arguments": "{\"path\": \"b.py\"}" }
    }
  ]
}
```

**Output:**

```json
{
  "type": "assistant",
  "message": {
    "content": [
      { "type": "tool_use", "name": "read_file", "id": "call_1", "input": { "path": "a.py" } },
      { "type": "tool_use", "name": "read_file", "id": "call_2", "input": { "path": "b.py" } }
    ],
    "id": "msg_a1b2c3d4e5f6a1b2c3d4e5f6"
  }
}
```

Each corresponding tool result is a separate message, each producing its own `user` record with a `tool_result` block.

### Error Detection in Tool Results

When the OpenAI message does not include an explicit `is_error` field, the adapter applies heuristic detection by scanning the first 500 characters of the content for error indicators:

- `Error:`, `error:`, `Traceback`, `Exception:`
- `FAILED`, `failed:`, `command not found`, `No such file`
- `Permission denied`, `ModuleNotFoundError`, `ImportError`
- `SyntaxError`, `TypeError`, `ValueError`, `KeyError`
- `FileNotFoundError`, `ConnectionError`, `TimeoutError`

If any indicator is found, `is_error: true` is added to the `tool_result` block.

**Input:**

```json
{
  "role": "tool",
  "content": "Traceback (most recent call last):\n  File \"app.py\", line 42\nTypeError: unsupported operand",
  "tool_call_id": "call_xyz"
}
```

**Output:**

```json
{
  "type": "user",
  "message": {
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "call_xyz",
        "content": "Traceback (most recent call last):\n  File \"app.py\", line 42\nTypeError: unsupported operand",
        "is_error": true
      }
    ]
  }
}
```

### Compression Summary Boundaries

When a user message starts with `[CONTEXT COMPACTION]` or `[CONTEXT SUMMARY]:`, it is recognized as a compression summary. The adapter inserts a `compact_boundary` system record before it, and marks the user record with `isCompactSummary: true`.

**Input:**

```json
{ "role": "user", "content": "[CONTEXT COMPACTION] The conversation covered..." }
```

**Output (two records):**

```json
{"type": "system", "subtype": "compact_boundary"}
{"type": "user", "isCompactSummary": true, "message": {"content": "[CONTEXT COMPACTION] The conversation covered..."}}
```

This tells VCC where compression boundaries exist in the conversation history, allowing it to produce views that respect the compacted vs. live context distinction.

### Malformed Tool Call Arguments

If `function.arguments` is not valid JSON, the adapter wraps the raw string in `{"raw": "<original string>"}` rather than failing.

**Input:**

```json
{
  "id": "call_bad",
  "type": "function",
  "function": { "name": "bash", "arguments": "not valid json {" }
}
```

**Output (in tool_use block):**

```json
{ "type": "tool_use", "name": "bash", "id": "call_bad", "input": { "raw": "not valid json {" } }
```

### Empty or Null Content

- `content: null` and `content: ""` are treated identically (empty string).
- An assistant message with no text content and no tool calls produces no output records.
- An assistant message with only tool calls (null content) works correctly -- only tool_use blocks appear.

### Timestamps

When the optional `timestamps` parameter is provided to `convert_conversation()`, each record receives a `"timestamp"` field with the corresponding ISO timestamp string. This is used for temporal ordering in VCC views.

### Synthetic Message IDs

Every assistant record receives a synthetic `message.id` in the format `msg_` followed by 24 hexadecimal characters (from `uuid4`). These IDs enable VCC's chunk-merging logic across multiple compilation passes.

### Tool Call ID to Tool Name Map

The adapter builds a `tool_call_id -> tool_name` mapping in a two-pass process:

1. **First pass:** Scans all assistant messages and extracts `tool_calls[].id` -> `tool_calls[].function.name`.
2. **Second pass:** Converts all messages, using the pre-built map to resolve tool names for tool_result records.

This ensures tool results can reference their originating tool name even if the messages are processed out of order.
