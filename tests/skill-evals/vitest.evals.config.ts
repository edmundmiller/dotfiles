import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["**/*.eval.ts"],
    reporters: ["default", "vitest-evals/reporter"],
    testTimeout: 180_000,
    hookTimeout: 180_000,
  },
});
