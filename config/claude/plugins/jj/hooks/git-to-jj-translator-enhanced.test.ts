import { assertEquals, assertExists } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import {
  parseGitCommand,
  classifyCommand,
  translateToJJ,
  CommandCategory,
  type ParsedCommand,
} from './git-to-jj-translator-enhanced.ts';

Deno.test('parseGitCommand - basic commands', () => {
  const result = parseGitCommand('git status');

  assertExists(result);
  assertEquals(result?.executable, 'git');
  assertEquals(result?.subcommand, 'status');
  assertEquals(result?.positional.length, 0);
});

Deno.test('parseGitCommand - command with message flag', () => {
  const result = parseGitCommand('git commit -m "test message"');

  assertExists(result);
  assertEquals(result?.subcommand, 'commit');
  assertEquals(result?.flags.get('m'), '"test');
});

Deno.test('parseGitCommand - command with long flag', () => {
  const result = parseGitCommand('git log --oneline');

  assertExists(result);
  assertEquals(result?.subcommand, 'log');
  assertEquals(result?.flags.get('oneline'), true);
});

Deno.test('parseGitCommand - command with -C flag', () => {
  const result = parseGitCommand('git -C /path/to/repo status');

  assertExists(result);
  assertEquals(result?.workdir, '/path/to/repo');
  assertEquals(result?.subcommand, 'status');
});

Deno.test('parseGitCommand - command with positional args', () => {
  const result = parseGitCommand('git checkout feature-branch');

  assertExists(result);
  assertEquals(result?.subcommand, 'checkout');
  assertEquals(result?.positional, ['feature-branch']);
});

Deno.test('parseGitCommand - command with multiple flags', () => {
  const result = parseGitCommand('git log --oneline --graph -n 10');

  assertExists(result);
  assertEquals(result?.subcommand, 'log');
  assertEquals(result?.flags.get('oneline'), true);
  assertEquals(result?.flags.get('graph'), true);
  assertEquals(result?.flags.get('n'), true);
});

Deno.test('parseGitCommand - non-git command returns null', () => {
  const result = parseGitCommand('ls -la');

  assertEquals(result, null);
});

Deno.test('classifyCommand - read-only commands', () => {
  const statusCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'status',
    flags: new Map(),
    positional: [],
  };

  assertEquals(classifyCommand(statusCmd), CommandCategory.READONLY);

  const logCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'log',
    flags: new Map(),
    positional: [],
  };

  assertEquals(classifyCommand(logCmd), CommandCategory.READONLY);
});

Deno.test('classifyCommand - destructive commands', () => {
  const resetCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'reset',
    flags: new Map([['hard', true]]),
    positional: [],
  };

  assertEquals(classifyCommand(resetCmd), CommandCategory.DESTRUCTIVE);

  const forcePushCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'push',
    flags: new Map([['force', true]]),
    positional: [],
  };

  assertEquals(classifyCommand(forcePushCmd), CommandCategory.DESTRUCTIVE);
});

Deno.test('classifyCommand - helper commands', () => {
  const commitCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'commit',
    flags: new Map(),
    positional: [],
  };

  assertEquals(classifyCommand(commitCmd), CommandCategory.HELPER);

  const addCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'add',
    flags: new Map(),
    positional: [],
  };

  assertEquals(classifyCommand(addCmd), CommandCategory.HELPER);
});

Deno.test('translateToJJ - basic translations', async () => {
  const checkoutCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'checkout',
    flags: new Map(),
    positional: ['branch-name'],
  };

  const result = await translateToJJ(checkoutCmd);
  assertEquals(result.includes('jj new'), true);
});

Deno.test('translateToJJ - push command', async () => {
  const pushCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'push',
    flags: new Map(),
    positional: [],
  };

  const result = await translateToJJ(pushCmd);
  assertEquals(result.includes('jj git push'), true);
});

Deno.test('translateToJJ - force push', async () => {
  const forcePushCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'push',
    flags: new Map([['force', true]]),
    positional: [],
  };

  const result = await translateToJJ(forcePushCmd);
  assertEquals(result.includes('--force'), true);
});

Deno.test('translateToJJ - pull/fetch', async () => {
  const pullCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'pull',
    flags: new Map(),
    positional: [],
  };

  const result = await translateToJJ(pullCmd);
  assertEquals(result.includes('jj git fetch'), true);
});

Deno.test('translateToJJ - branch listing', async () => {
  const branchCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'branch',
    flags: new Map([['a', true]]),
    positional: [],
  };

  const result = await translateToJJ(branchCmd);
  assertEquals(result.includes('jj bookmark list'), true);
});

Deno.test('translateToJJ - merge to rebase', async () => {
  const mergeCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'merge',
    flags: new Map(),
    positional: ['feature'],
  };

  const result = await translateToJJ(mergeCmd);
  assertEquals(result.includes('jj rebase'), true);
});

Deno.test('translateToJJ - stash to new', async () => {
  const stashCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'stash',
    flags: new Map(),
    positional: [],
  };

  const result = await translateToJJ(stashCmd);
  assertEquals(result.includes('jj new'), true);
});

Deno.test('translateToJJ - reset --hard', async () => {
  const resetCmd: ParsedCommand = {
    executable: 'git',
    subcommand: 'reset',
    flags: new Map([['hard', true]]),
    positional: [],
  };

  const result = await translateToJJ(resetCmd);
  assertEquals(result.includes('jj abandon'), true);
});

Deno.test('parseGitCommand - complex real-world commands', () => {
  const complexCmd = 'git -C ~/project commit -m "feat: add feature" --no-verify';
  const result = parseGitCommand(complexCmd);

  assertExists(result);
  assertEquals(result?.workdir, '~/project');
  assertEquals(result?.subcommand, 'commit');
  assertEquals(result?.flags.has('m'), true);
  assertEquals(result?.flags.has('no-verify'), true);
});

Deno.test('parseGitCommand - with -- separator', () => {
  const cmd = 'git checkout -- file.txt';
  const result = parseGitCommand(cmd);

  assertExists(result);
  assertEquals(result?.subcommand, 'checkout');
  assertEquals(result?.positional, ['file.txt']);
});

Deno.test('classifyCommand - edge cases', () => {
  // Empty subcommand should default to helper
  const emptyCmd: ParsedCommand = {
    executable: 'git',
    subcommand: '',
    flags: new Map(),
    positional: [],
  };

  assertEquals(classifyCommand(emptyCmd), CommandCategory.HELPER);
});
