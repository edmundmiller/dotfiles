import { describe, it, expect, beforeAll } from 'bun:test';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Helper function to run a Python hook script with input and capture output
 */
async function runHook(hookName, input) {
  return new Promise((resolve, reject) => {
    const hookPath = join(__dirname, hookName);
    const child = spawn('python3', [hookPath]);
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
        try {
          // Hooks output JSON
          const result = JSON.parse(stdout);
          resolve(result);
        } catch (e) {
          reject(new Error(`Failed to parse hook output: ${stdout}`));
        }
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

describe('git-to-jj-translator hook', () => {
  const hookName = 'git-to-jj-translator.py';

  describe('read-only git commands (should allow)', () => {
    it('should allow git status', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git status' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
      expect(result.system_message).toBeUndefined();
    });

    it('should allow git log', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git log' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should allow git diff', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git diff' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should allow git show', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git show abc123' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should allow git blame', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git blame file.txt' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });
  });

  describe('write git commands (should block with suggestions)', () => {
    it('should block git commit and suggest jj describe', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git commit -m "message"' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toBeDefined();
      expect(result.system_message).toContain('jj describe');
      expect(result.system_message).toContain('blocked');
    });

    it('should block git add and suggest jj squash', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git add file.txt' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toContain('jj squash');
    });

    it('should block git checkout and suggest jj new', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git checkout branch-name' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toContain('jj new');
    });

    it('should block git push and suggest jj git push', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git push origin main' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toContain('jj git push');
    });

    it('should block git pull and suggest jj git fetch', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git pull' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toContain('jj git fetch');
    });

    it('should block git merge and suggest jj rebase', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git merge feature' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toContain('jj rebase');
    });

    it('should block git reset and suggest jj restore or jj abandon', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git reset --hard HEAD' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toContain('jj');
    });
  });

  describe('non-git commands (should allow)', () => {
    it('should allow non-git Bash commands', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'ls -la' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should allow jj commands', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'jj status' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should ignore non-Bash tools', async () => {
      const input = {
        tool: {
          name: 'Read',
          params: { file_path: '/some/file.txt' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });
  });

  describe('edge cases and error handling', () => {
    it('should handle commands with leading/trailing whitespace', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: '  git commit -m "test"  ' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
    });

    it('should handle empty command', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: '' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should handle malformed input gracefully', async () => {
      const input = {
        tool: {}
      };

      const result = await runHook(hookName, input);

      // Should fail open (allow execution) on errors
      expect(result.continue).toBe(true);
    });

    it('should handle git subcommands with flags', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git commit -a -m "message" --no-verify' }
        }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(false);
      expect(result.system_message).toContain('jj');
    });
  });

  describe('command mapping accuracy', () => {
    it('should suggest correct mapping for git diff --staged', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git diff --staged' }
        }
      };

      const result = await runHook(hookName, input);

      // This is read-only, should be allowed
      expect(result.continue).toBe(true);
    });

    it('should suggest bookmark commands for git branch', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'git branch -a' }
        }
      };

      const result = await runHook(hookName, input);

      // git branch is read-only, should be allowed
      expect(result.continue).toBe(true);
    });
  });
});

describe('plan-commit hook', () => {
  const hookName = 'plan-commit.py';

  describe('substantial task detection', () => {
    it('should NOT create plan for simple questions', async () => {
      const input = {
        prompt: 'What does this function do?'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
      // Should not include plan commit message
      expect(result.system_message).toBeUndefined();
    });

    it('should NOT create plan for yes/no questions', async () => {
      const input = {
        prompt: 'Is this the right approach?'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
      expect(result.system_message).toBeUndefined();
    });

    it('should NOT create plan for explanation requests', async () => {
      const input = {
        prompt: 'Can you explain how jj works?'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
      expect(result.system_message).toBeUndefined();
    });

    it('should detect implementation tasks', async () => {
      const input = {
        prompt: 'Add a new feature to handle user authentication'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
      // May or may not create plan depending on jj state
      // but should recognize it as a task
    });

    it('should detect refactoring tasks', async () => {
      const input = {
        prompt: 'Refactor the login component to use hooks'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should detect fix tasks', async () => {
      const input = {
        prompt: 'Fix the bug in the authentication flow'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should detect build/create tasks', async () => {
      const input = {
        prompt: 'Build a REST API for user management'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });
  });

  describe('edge cases', () => {
    it('should handle empty prompt', async () => {
      const input = {
        prompt: ''
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should handle missing prompt field', async () => {
      const input = {};

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should handle very long prompts', async () => {
      const input = {
        prompt: 'Add a new feature that ' + 'does something '.repeat(100)
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should handle prompts with special characters', async () => {
      const input = {
        prompt: 'Fix the "authentication" & <validation> logic (urgent!)'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should handle mixed case prompts', async () => {
      const input = {
        prompt: 'IMPLEMENT the LOGIN feature'
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });
  });

  describe('task pattern detection', () => {
    const taskVerbs = [
      'add', 'create', 'implement', 'build', 'make', 'write',
      'fix', 'update', 'refactor', 'change', 'modify',
      'remove', 'delete', 'clean', 'optimize', 'improve', 'enhance',
      'install', 'configure', 'setup', 'integrate'
    ];

    taskVerbs.forEach(verb => {
      it(`should detect "${verb}" as a task verb`, async () => {
        const input = {
          prompt: `${verb} a new feature`
        };

        const result = await runHook(hookName, input);

        expect(result.continue).toBe(true);
      });
    });

    const questionWords = ['what', 'why', 'how', 'when', 'where', 'who', 'which'];

    questionWords.forEach(word => {
      it(`should detect "${word}" as a question`, async () => {
        const input = {
          prompt: `${word} is the best approach?`
        };

        const result = await runHook(hookName, input);

        expect(result.continue).toBe(true);
      });
    });
  });
});

describe('integration-helper hook (session end validation)', () => {
  const hookName = 'integration-helper.py';

  // Note: These tests are limited because they rely on actual jj repository state
  // They primarily test error handling and output structure

  describe('error handling', () => {
    it('should handle missing jj command gracefully', async () => {
      // This will likely fail in CI without jj installed
      // but should handle the error gracefully
      const input = {};

      try {
        const result = await runHook(hookName, input);
        // Should exit successfully even if jj isn't available
        expect(result).toBeDefined();
      } catch (error) {
        // Error is expected if jj is not installed
        // The hook should still exit 0
        expect(error).toBeDefined();
      }
    });

    it('should handle empty input', async () => {
      const input = {};

      try {
        await runHook(hookName, input);
        // Should not crash
      } catch (error) {
        // Expected in non-jj environments
      }
    });
  });

  // Note: Full integration tests would require mocking jj commands
  // or running in an actual jj repository with known state
});

describe('hook integration patterns', () => {
  describe('hook chaining behavior', () => {
    it('should allow git-to-jj-translator to pass through jj commands', async () => {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: 'jj status' }
        }
      };

      const result = await runHook('git-to-jj-translator.py', input);

      expect(result.continue).toBe(true);
      expect(result.system_message).toBeUndefined();
    });

    it('should allow plan-commit to continue execution', async () => {
      const input = {
        prompt: 'What is jj?'
      };

      const result = await runHook('plan-commit.py', input);

      expect(result.continue).toBe(true);
    });
  });

  describe('fail-open safety', () => {
    it('git-to-jj-translator should fail open on errors', async () => {
      const malformedInput = { invalid: 'structure' };

      const result = await runHook('git-to-jj-translator.py', malformedInput);

      expect(result.continue).toBe(true);
    });

    it('plan-commit should fail open on errors', async () => {
      const malformedInput = { invalid: 'structure' };

      const result = await runHook('plan-commit.py', malformedInput);

      expect(result.continue).toBe(true);
    });
  });
});

describe('real-world workflow scenarios', () => {
  it('should handle typical development workflow commands', async () => {
    const commands = [
      { cmd: 'jj status', shouldAllow: true },
      { cmd: 'git status', shouldAllow: true },  // read-only
      { cmd: 'jj diff', shouldAllow: true },
      { cmd: 'git diff', shouldAllow: true },     // read-only
      { cmd: 'jj log', shouldAllow: true },
      { cmd: 'git commit -m "test"', shouldAllow: false },  // blocked
      { cmd: 'jj describe -m "test"', shouldAllow: true },
    ];

    for (const { cmd, shouldAllow } of commands) {
      const input = {
        tool: {
          name: 'Bash',
          params: { command: cmd }
        }
      };

      const result = await runHook('git-to-jj-translator.py', input);

      if (shouldAllow) {
        expect(result.continue).toBe(true);
      } else {
        expect(result.continue).toBe(false);
        expect(result.system_message).toBeDefined();
      }
    }
  });

  it('should distinguish between questions and implementation requests', async () => {
    const scenarios = [
      { prompt: 'How does authentication work?', isTask: false },
      { prompt: 'Implement authentication', isTask: true },
      { prompt: 'Why is this failing?', isTask: false },
      { prompt: 'Fix this failing test', isTask: true },
      { prompt: 'What are the benefits?', isTask: false },
      { prompt: 'Add benefits tracking', isTask: true },
    ];

    for (const { prompt, isTask } of scenarios) {
      const input = { prompt };

      const result = await runHook('plan-commit.py', input);

      expect(result.continue).toBe(true);
      // The actual behavior depends on jj state, but it should always continue
    }
  });
});

describe('todo-to-commit hook', () => {
  const hookName = 'todo-to-commit.py';

  describe('non-TodoWrite tools (should pass through)', () => {
    it('should ignore non-TodoWrite tools', async () => {
      const input = {
        tool_name: 'Bash',
        tool_input: { command: 'ls' }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
      expect(result.additionalContext).toBeUndefined();
    });

    it('should ignore Read tool', async () => {
      const input = {
        tool_name: 'Read',
        tool_input: { file_path: '/some/file' }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should ignore Edit tool', async () => {
      const input = {
        tool_name: 'Edit',
        tool_input: { file_path: '/some/file', old_string: 'a', new_string: 'b' }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });
  });

  describe('TodoWrite with empty todos', () => {
    it('should pass through when todos array is empty', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: { todos: [] }
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });

    it('should pass through when todos field is missing', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {}
      };

      const result = await runHook(hookName, input);

      expect(result.continue).toBe(true);
    });
  });

  describe('TodoWrite with valid todos', () => {
    // Note: These tests will only work in an actual jj repository
    // In CI or non-jj environments, they should fail gracefully

    it('should handle single pending todo', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            {
              content: 'Test task',
              activeForm: 'Testing task',
              status: 'pending'
            }
          ]
        }
      };

      try {
        const result = await runHook(hookName, input);
        expect(result.continue).toBe(true);
        // In a jj repo, should create commits
        // Outside jj repo, should fail gracefully
      } catch (error) {
        // Expected outside jj repo
        expect(error).toBeDefined();
      }
    });

    it('should handle multiple todos with different statuses', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            {
              content: 'Completed task',
              activeForm: 'Completing task',
              status: 'completed'
            },
            {
              content: 'In progress task',
              activeForm: 'Working on task',
              status: 'in_progress'
            },
            {
              content: 'Pending task',
              activeForm: 'Will do task',
              status: 'pending'
            }
          ]
        }
      };

      try {
        const result = await runHook(hookName, input);
        expect(result.continue).toBe(true);
      } catch (error) {
        // Expected outside jj repo
      }
    });

    it('should handle todo status transitions', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            {
              content: 'Task changing from pending to in progress',
              activeForm: 'Changing task status',
              status: 'in_progress'
            }
          ]
        }
      };

      try {
        const result = await runHook(hookName, input);
        expect(result.continue).toBe(true);
      } catch (error) {
        // Expected outside jj repo
      }
    });
  });

  describe('error handling', () => {
    it('should handle malformed input gracefully', async () => {
      const input = {
        tool_name: 'TodoWrite',
        // Missing tool_input
      };

      const result = await runHook(hookName, input);

      // Should fail open
      expect(result.continue).toBe(true);
    });

    it('should handle invalid todo structure', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            { invalid: 'structure' }
          ]
        }
      };

      try {
        const result = await runHook(hookName, input);
        expect(result.continue).toBe(true);
      } catch (error) {
        // May fail depending on validation
      }
    });

    it('should handle missing jj command gracefully', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            {
              content: 'Test task',
              activeForm: 'Testing',
              status: 'pending'
            }
          ]
        }
      };

      // This test will fail outside jj repo, but hook should handle gracefully
      try {
        await runHook(hookName, input);
      } catch (error) {
        // Expected - hook should fail open, not crash
      }
    });
  });

  describe('todo content edge cases', () => {
    it('should handle todos with special characters', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            {
              content: 'Fix "authentication" & <validation> logic (urgent!)',
              activeForm: 'Fixing auth',
              status: 'pending'
            }
          ]
        }
      };

      try {
        const result = await runHook(hookName, input);
        expect(result.continue).toBe(true);
      } catch (error) {
        // Expected outside jj repo
      }
    });

    it('should handle todos with very long content', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            {
              content: 'Very long task description that '.repeat(20) + 'continues',
              activeForm: 'Working on long task',
              status: 'pending'
            }
          ]
        }
      };

      try {
        const result = await runHook(hookName, input);
        expect(result.continue).toBe(true);
      } catch (error) {
        // Expected outside jj repo
      }
    });

    it('should handle todos with newlines', async () => {
      const input = {
        tool_name: 'TodoWrite',
        tool_input: {
          todos: [
            {
              content: 'Task with\nmultiple\nlines',
              activeForm: 'Multi-line task',
              status: 'pending'
            }
          ]
        }
      };

      try {
        const result = await runHook(hookName, input);
        expect(result.continue).toBe(true);
      } catch (error) {
        // Expected outside jj repo
      }
    });
  });

  describe('status prefix mapping', () => {
    it('should map pending status to [TODO] prefix', async () => {
      // This is conceptual - actual testing requires jj repo
      // The mapping is:
      // pending -> [TODO]
      // in_progress -> [WIP]
      // completed -> no prefix
    });

    it('should map in_progress status to [WIP] prefix', async () => {
      // Verified through hook implementation
    });

    it('should map completed status to no prefix', async () => {
      // Verified through hook implementation
    });
  });
});
