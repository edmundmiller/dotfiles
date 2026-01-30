# Claude Code JSON-to-TOON Hook

Automatically converts JSON in your Claude Code prompts to [TOON format](https://github.com/johannschopplich/toon) for **30-60% token savings**.

## What is TOON?

TOON (Token-Oriented Object Notation) is a compact data format optimized for LLMs. Instead of repeating field names in every object, TOON declares them once and streams values as rows.

**Example:**

JSON (117 tokens):

```json
{
  "products": [
    { "sku": "A123", "name": "Widget", "price": 9.99 },
    { "sku": "B456", "name": "Gadget", "price": 19.99 }
  ]
}
```

TOON (49 tokens - 58% reduction):

```
products[2]{sku,name,price}:
  A123,Widget,9.99
  B456,Gadget,19.99
```

## Features

- ✅ Automatically detects and converts JSON in prompts
- ✅ Handles JSON code blocks (` ```json `)
- ✅ Handles inline JSON objects/arrays
- ✅ Converts CSV data to TOON format
- ✅ Converts Markdown tables to TOON format
- ✅ Smart detection: preserves JavaScript/TypeScript code
- ✅ Safe: fails gracefully, never breaks prompts
- ✅ Zero configuration after setup

## Prerequisites

- [Claude Code](https://docs.claude.com/en/docs/claude-code)
- Node.js (any recent version)

## Installation

### 1. Create hooks directory

```bash
mkdir -p ~/.claude/hooks
```

### 2. Download the TOON library

```bash
curl -sL https://esm.sh/@byjohann/toon@latest/es2015/toon.mjs -o ~/.claude/hooks/toon.mjs
```

### 3. Download the hook script

```bash
curl -sL https://gist.githubusercontent.com/maman/de31d48cd960366ce9caec32b569d32a/raw/json-to-toon.mjs -o ~/.claude/hooks/json-to-toon.mjs
chmod +x ~/.claude/hooks/json-to-toon.mjs
```

### 4. Configure Claude Code

Add the following to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/hooks/json-to-toon.mjs"
          }
        ]
      }
    ]
  }
}
```

If your `settings.json` already has a `hooks` section, merge the `UserPromptSubmit` configuration into it.

## How It Works

The hook runs automatically before each prompt is sent to Claude:

1. **Detects structured data** in your prompt:
   - **JSON**: Code blocks with ` ```json ` identifier, plain code blocks containing valid JSON, or inline JSON objects/arrays (30+ characters)
   - **CSV**: Code blocks with ` ```csv ` identifier or plain code blocks with comma/tab/pipe-delimited data
   - **Markdown tables**: Standard markdown table syntax with header, separator, and data rows

2. **Converts to TOON** format using optimized parsing

3. **Preserves non-data content**:
   - JavaScript/TypeScript code (detected via keywords)
   - Plain text
   - Other code blocks

4. **Sends modified prompt** to Claude with reduced token count

## Examples

### Example 1: JSON Code Block

**You type:**

````
Analyze this data:
\```json
{
  "users": [
    {"id": 1, "name": "Alice", "active": true},
    {"id": 2, "name": "Bob", "active": false}
  ]
}
\```
````

**Claude receives:**

````
Analyze this data:
\```
users[2]{id,name,active}:
  1,Alice,true
  2,Bob,false
\```
````

### Example 2: Inline JSON

**You type:**

```
Process this: {"products": [{"sku": "A123", "name": "Widget", "price": 9.99}], "total": 1}
```

**Claude receives:**

```
Process this: products[1]{sku,name,price}:
  A123,Widget,9.99
total: 1
```

### Example 3: JavaScript Code (Not Converted)

**You type:**

```javascript
function getData() {
  return { users: [] };
}
```

**Claude receives:** (unchanged)

```javascript
function getData() {
  return { users: [] };
}
```

### Example 4: CSV Data

**You type:**

````
Analyze this sales data:
\```csv
product,quantity,revenue
Widget,150,1485.00
Gadget,89,1780.11
Tool,234,3510.00
\```
````

**Claude receives:**

````
Analyze this sales data:
\```
[3]{product,quantity,revenue}:
  Widget,150,1485
  Gadget,89,1780.11
  Tool,234,3510
\```
````

### Example 5: Markdown Tables

**You type:**

```
Compare these database options:

| Database  | Type      | Max Connections |
|-----------|-----------|-----------------|
| PostgreSQL| Relational| 100             |
| MongoDB   | Document  | 500             |
| Redis     | Key-Value | 10000           |
```

**Claude receives:**

```
Compare these database options:

[3]{Database,Type,Max Connections}:
  PostgreSQL,Relational,100
  MongoDB,Document,500
  Redis,Key-Value,10000
```

## Troubleshooting

### Hook not running?

1. Verify Node.js is installed: `node --version`
2. Check script exists: `ls -lh ~/.claude/hooks/json-to-toon.mjs`
3. Check script is executable: `chmod +x ~/.claude/hooks/json-to-toon.mjs`
4. Verify settings.json syntax is valid JSON

### Test the hook manually:

```bash
echo '{"prompt": "Test: {\"key\": \"value\", \"items\": [{\"a\": 1}, {\"a\": 2}]}"}' | node ~/.claude/hooks/json-to-toon.mjs
```

Expected output:

```
Test: key: value
items[2]{a}:
  1
  2
```

## Credits

- Hook implementation: This gist
- TOON format: [@johannschopplich/toon](https://github.com/johannschopplich/toon)
- Claude Code: [Anthropic](https://docs.claude.com/en/docs/claude-code)

## License

MIT - Use freely, no attribution required.
