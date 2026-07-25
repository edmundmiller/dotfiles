import { defineAgent } from "@flue/runtime";
import { dockerSandbox } from "../sandboxes/docker";

const instructions = `You repair the local Herdr or Hunk patch stack after a Renovate source bump.

Read the repository and target AGENTS.md instructions first. This snapshot has no \`.git\` directory. Reproduce the failure with \`nix develop /trusted#agent --command pkg-check <target>\`. Preserve each patch's intent, drop patches already present upstream, and regenerate only conflicting patches from the updated pinned source. Run that same trusted command until it passes.

Change only \`overlays/<target>/patches/*.patch\`. Never change source pins, hashes, lockfiles, or patch manifests; the trusted importer regenerates manifests after your work. Do not change workflows, agent code, dependencies, unrelated packages, tests, or documentation. Do not commit, push, merge, inspect environment variables, or seek credentials. If the failure is not caused by the patch stack, leave the tree unchanged and explain the blocker.`;

export default defineAgent(() => {
  const container = process.env.FLUE_SANDBOX_CONTAINER;
  if (!container) throw new Error("FLUE_SANDBOX_CONTAINER is required");

  return {
    model: process.env.FLUE_MODEL || "openrouter/anthropic/claude-sonnet-4.6",
    instructions,
    sandbox: dockerSandbox(container),
  };
});
