# Vitest Skill Evals

Vitest Evals template for checking whether a Pi-compatible agent follows the Vitest skill.

## Install

```bash
pnpm add -D vitest vitest-evals @vitest-evals/harness-pi-ai
```

## Config

```ts
// vitest.evals.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["evals/**/*.eval.ts"],
    testTimeout: 30_000,
    hookTimeout: 30_000,
    reporters: ["vitest-evals/reporter"],
    env: {
      VITEST_EVALS_REPLAY_MODE: process.env.VITEST_EVALS_REPLAY_MODE ?? "auto",
      VITEST_EVALS_REPLAY_DIR: ".vitest-evals/recordings",
    },
  },
});
```

## Use

Copy `skill.eval.ts` into the consuming project, replace `createVitestSkillAgent()` with the real Pi-compatible agent factory, then run:

```bash
vitest run --config vitest.evals.config.ts
```
