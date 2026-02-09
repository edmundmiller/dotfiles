/**
 * enforce-commit-signing Extension
 *
 * Blocks git commit commands when SSH signing would fail.
 * Prevents unsigned commits by verifying op-ssh-sign is available
 * before allowing any git commit to proceed.
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";
import { execSync } from "node:child_process";

export default function (pi: ExtensionAPI) {
  const commitPattern = /\bgit\s+commit\b/i;

  function isSigningAvailable(): boolean {
    try {
      // op-ssh-sign doesn't support --version; --help is stable and exits 0 when present.
      execSync("/Applications/1Password.app/Contents/MacOS/op-ssh-sign --help", {
        stdio: "pipe",
        timeout: 5000,
      });
      return true;
    } catch {
      return false;
    }
  }

  function isGpgSignEnabled(): boolean {
    try {
      const result = execSync("git config --get commit.gpgsign", {
        stdio: "pipe",
        timeout: 3000,
      })
        .toString()
        .trim();
      return result === "true";
    } catch {
      return false;
    }
  }

  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return undefined;

    const command = event.input.command;
    if (!commitPattern.test(command)) return undefined;

    if (!isGpgSignEnabled()) {
      return {
        block: true,
        reason: "commit.gpgsign is not enabled in git config. All commits must be signed.",
      };
    }

    if (!isSigningAvailable()) {
      return {
        block: true,
        reason:
          "1Password SSH signing (op-ssh-sign) is not available. " +
          "Ensure 1Password is running and unlocked before committing.",
      };
    }

    return undefined;
  });

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    const signingOk = isSigningAvailable();
    const gpgSign = isGpgSignEnabled();

    if (signingOk && gpgSign) {
      ctx.ui.notify("🔐 Commit signing: ✅ ready", "info");
    } else {
      const issues = [];
      if (!gpgSign) issues.push("commit.gpgsign not enabled");
      if (!signingOk) issues.push("op-ssh-sign not available");
      ctx.ui.notify(`🔐 Commit signing: ⚠️ ${issues.join(", ")}`, "warning");
    }
  });
}
