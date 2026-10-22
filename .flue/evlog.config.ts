import { defineEvlog } from "evlog";

export default defineEvlog({
  service: "dotfiles-flue",
  pretty: false,
  silent: true,
  // Accounting events must never be sampled. Content is excluded at the adapter.
  sampling: { rates: { info: 100, warn: 100, error: 100 } },
  redact: true,
  logs: { dir: ".evlog/logs" },
  map: { minScore: 100, ignore: ["**/*.test.ts", "tests/**"] },
});
