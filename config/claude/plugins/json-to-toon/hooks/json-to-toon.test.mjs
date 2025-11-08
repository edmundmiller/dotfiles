import { describe, it, expect } from 'vitest';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const hookPath = join(__dirname, 'json-to-toon.mjs');

/**
 * Helper function to run the hook script with input and capture output
 */
async function runHook(input) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', [hookPath]);
    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Hook exited with code ${code}: ${stderr}`));
      } else {
        // Hook outputs plain text prompt, not JSON
        // Trim trailing newline added by console.log()
        // Wrap it back into an object for easier testing
        resolve({ prompt: stdout.trimEnd() });
      }
    });

    child.on('error', (error) => {
      reject(error);
    });

    // Send input to stdin
    child.stdin.write(JSON.stringify(input));
    child.stdin.end();
  });
}

describe('json-to-toon hook integration tests', () => {
  describe('JSON code block detection and conversion', () => {
    it('should convert JSON code blocks with json identifier', async () => {
      const input = {
        prompt: 'Analyze this data:\n```json\n{"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]}\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('users[2]{id,name}:');
      expect(result.prompt).toContain('1,Alice');
      expect(result.prompt).toContain('2,Bob');
      expect(result.prompt).not.toContain('```json');
    });

    it('should convert plain code blocks containing valid JSON', async () => {
      const input = {
        prompt: 'Check this:\n```\n{"data": [1, 2, 3, 4, 5]}\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('data[5]:');
      expect(result.prompt).toContain('1,2,3,4,5');
    });

    it('should convert multiple JSON code blocks in same prompt', async () => {
      const input = {
        prompt: 'First:\n```json\n{"a": 1}\n```\nSecond:\n```json\n{"b": 2}\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('a:');
      expect(result.prompt).toContain('b:');
    });
  });

  describe('inline JSON conversion', () => {
    it('should convert inline JSON ≥30 characters', async () => {
      const input = {
        prompt: 'Process this object: {"products": [{"sku": "A123", "price": 9.99}]}'
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('products[1]{sku,price}:');
      expect(result.prompt).toContain('A123,9.99');
    });

    it('should NOT convert small inline JSON <30 characters', async () => {
      const input = {
        prompt: 'Here is a small object: {"a": 1, "b": 2}'
      };

      const result = await runHook(input);

      expect(result.prompt).toBe(input.prompt);
    });

    it('should convert inline JSON arrays', async () => {
      const input = {
        prompt: 'Array data: [{"x": 10, "y": 20}, {"x": 30, "y": 40}]'
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('[2]{x,y}:');
      expect(result.prompt).toContain('10,20');
      expect(result.prompt).toContain('30,40');
    });
  });

  describe('code preservation (avoid false positives)', () => {
    it('should NOT convert JavaScript code with const', async () => {
      const input = {
        prompt: '```javascript\nconst config = { port: 3000, host: "localhost" };\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toBe(input.prompt);
      expect(result.prompt).toContain('const config');
    });

    it('should NOT convert JavaScript code with function', async () => {
      const input = {
        prompt: '```javascript\nfunction getData() { return { items: [1, 2, 3] }; }\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toBe(input.prompt);
      expect(result.prompt).toContain('function getData');
    });

    it('should NOT convert TypeScript code with arrow functions', async () => {
      const input = {
        prompt: '```typescript\nconst handler = (data: any) => { return { result: data }; };\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toBe(input.prompt);
      expect(result.prompt).toContain('const handler');
    });

    it('should NOT convert code with let/var declarations', async () => {
      const input = {
        prompt: '```javascript\nlet state = { count: 0 };\nvar options = { debug: true };\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toBe(input.prompt);
    });
  });

  describe('error handling and edge cases', () => {
    it('should handle invalid JSON gracefully', async () => {
      const input = {
        prompt: '```json\n{invalid json here: missing quotes}\n```'
      };

      const result = await runHook(input);

      // Should return original prompt when JSON is invalid
      expect(result.prompt).toBe(input.prompt);
    });

    it('should handle empty objects', async () => {
      const input = {
        prompt: '```json\n{}\n```'
      };

      const result = await runHook(input);

      // Empty objects should either convert or be preserved
      expect(result.prompt).toBeDefined();
    });

    it('should handle empty arrays', async () => {
      const input = {
        prompt: '```json\n[]\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toBeDefined();
    });

    it('should handle prompts without any JSON', async () => {
      const input = {
        prompt: 'This is just plain text without any JSON structures.'
      };

      const result = await runHook(input);

      expect(result.prompt).toBe(input.prompt);
    });

    it('should handle malformed input structure', async () => {
      const input = {
        // Missing prompt field - should fail gracefully
        message: 'This is wrong structure'
      };

      const result = await runHook(input);

      // Hook should handle missing prompt field
      expect(result).toBeDefined();
    });
  });

  describe('real-world data scenarios', () => {
    it('should convert API response format', async () => {
      const input = {
        prompt: `API returned: \`\`\`json
{
  "status": "success",
  "data": {
    "users": [
      {"id": 1, "email": "alice@example.com", "active": true},
      {"id": 2, "email": "bob@example.com", "active": false}
    ]
  },
  "meta": {"total": 2, "page": 1}
}
\`\`\``
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('users[2]{id,email,active}:');
      expect(result.prompt).toContain('alice@example.com');
      expect(result.prompt).toContain('bob@example.com');
    });

    it('should convert configuration file format', async () => {
      const input = {
        prompt: `Config file:
\`\`\`json
{
  "server": {
    "port": 8080,
    "host": "0.0.0.0"
  },
  "database": {
    "url": "postgres://localhost/mydb",
    "pool": {"min": 2, "max": 10}
  }
}
\`\`\``
      };

      const result = await runHook(input);

      // TOON format for nested objects uses indentation
      expect(result.prompt).toContain('server:');
      expect(result.prompt).toContain('8080');
      expect(result.prompt).toContain('0.0.0.0');
      expect(result.prompt).toContain('database:');
      expect(result.prompt).toContain('postgres://localhost/mydb');
    });

    it('should handle mixed content (text + JSON + code)', async () => {
      const input = {
        prompt: `Here's the analysis:

The data structure:
\`\`\`json
{"metrics": [{"name": "cpu", "value": 85.5}, {"name": "memory", "value": 62.3}]}
\`\`\`

And here's the processing code:
\`\`\`javascript
function processMetrics(data) {
  return data.metrics.map(m => m.value);
}
\`\`\`

What do you think?`
      };

      const result = await runHook(input);

      // JSON should be converted
      expect(result.prompt).toContain('metrics[2]{name,value}:');

      // JavaScript should be preserved
      expect(result.prompt).toContain('function processMetrics');

      // Regular text should be preserved
      expect(result.prompt).toContain('Here\'s the analysis');
      expect(result.prompt).toContain('What do you think');
    });
  });

  describe('data structure types', () => {
    it('should convert nested objects', async () => {
      const input = {
        prompt: `\`\`\`json
{
  "company": {
    "name": "Acme Corp",
    "employees": [
      {"name": "Alice", "role": "Engineer"},
      {"name": "Bob", "role": "Designer"}
    ]
  }
}
\`\`\``
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('employees[2]{name,role}:');
      expect(result.prompt).toContain('Alice,Engineer');
    });

    it('should convert arrays of primitives', async () => {
      const input = {
        prompt: '```json\n{"numbers": [1, 2, 3, 4, 5], "strings": ["a", "b", "c"]}\n```'
      };

      const result = await runHook(input);

      expect(result.prompt).toContain('numbers[5]:');
      expect(result.prompt).toContain('1,2,3,4,5');
    });

    it('should handle null and boolean values', async () => {
      const input = {
        prompt: '```json\n{"enabled": true, "disabled": false, "value": null}\n```'
      };

      const result = await runHook(input);

      // TOON should handle these primitive types
      expect(result.prompt).toBeDefined();
      expect(result.prompt.length).toBeGreaterThan(0);
    });
  });

  describe('minimum size threshold (30 characters)', () => {
    it('should respect 30 char threshold for inline JSON', async () => {
      // Exactly 29 chars - should NOT convert
      const shortInput = {
        prompt: '{"a":1,"b":2,"c":3,"d":4}' // 25 chars
      };

      const shortResult = await runHook(shortInput);
      expect(shortResult.prompt).toBe(shortInput.prompt);

      // 40+ chars - should convert
      const longInput = {
        prompt: '{"products":[{"sku":"A123","price":9.99}]}' // 44 chars
      };

      const longResult = await runHook(longInput);
      expect(longResult.prompt).not.toBe(longInput.prompt);
      expect(longResult.prompt).toContain('products[1]{sku,price}:');
    });

    it('should always convert code blocks regardless of size', async () => {
      const input = {
        prompt: '```json\n{"x":1}\n```'
      };

      const result = await runHook(input);

      // Even small JSON in code blocks should be converted
      expect(result.prompt).not.toBe(input.prompt);
    });
  });
});
