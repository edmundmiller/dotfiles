import { createJevPlugin } from "oxlint-plugin-jev";

import rules from "./rules.json" with { type: "json" };

import type { JevRule } from "oxlint-plugin-jev";

// Keep the repository's questions and thresholds separate from upstream presets.
export default createJevPlugin({
  name: "jev",
  ci: "skip",
  changedOnly: true,
  // SAFETY: tests.test_oxlint_jev checks every JSON target and cutoff against Jev's contract.
  rules: rules as JevRule[],
});
