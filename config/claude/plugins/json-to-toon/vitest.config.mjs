import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Test file patterns
    include: ['**/*.test.mjs', '**/*.spec.mjs'],

    // Timeout for tests that spawn child processes
    testTimeout: 5000,

    // Reporter configuration
    reporters: ['verbose'],

    // Environment
    environment: 'node',

    // Coverage configuration (optional)
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['hooks/**/*.mjs'],
      exclude: ['hooks/**/*.test.mjs', 'hooks/**/*.spec.mjs'],
    },
  },
});
