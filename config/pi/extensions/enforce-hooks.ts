/**
 * enforce-hooks Extension
 *
 * Hard-blocks any attempt to bypass git hooks or signing.
 * Mirrors the deny rules from opencode.jsonc permissions.
 *
 * Blocked patterns:
 * - --no-verify / -n on commit and push
 * - --no-gpg-sign on commit and push
 * - commit.gpgsign=false via -c flag
 * - --author overrides on commit
 * - GIT_AUTHOR / GIT_COMMITTER env overrides
 * - HUSKY=0, SKIP, PRE_COMMIT_ALLOW_NO_CONFIG env bypasses
 * - core.hooksPath manipulation
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { isToolCallEventType } from "@mariozechner/pi-coding-agent";

interface DenyRule {
  pattern: RegExp;
  reason: string;
}

const DENY_RULES: DenyRule[] = [
  // --no-verify / -n on commit
  {
    pattern: /\bgit\s+commit\b.*\s(--no-verify|-n)\b/i,
    reason: "git commit --no-verify is blocked. Pre-commit hooks must run.",
  },
  {
    pattern: /\bgit\s+commit\b.*\s-[a-mo-zA-Z]*n/i, // -n combined with other short flags
    reason: "git commit -n (--no-verify) is blocked. Pre-commit hooks must run.",
  },
  // --no-verify on push
  {
    pattern: /\bgit\s+push\b.*--no-verify\b/i,
    reason: "git push --no-verify is blocked. Pre-push hooks must run.",
  },
  // --no-gpg-sign on commit/push
  {
    pattern: /\bgit\s+(commit|push)\b.*--no-gpg-sign\b/i,
    reason: "--no-gpg-sign is blocked. All commits/pushes must be signed.",
  },
  // -c commit.gpgsign=false
  {
    pattern: /\bgit\s+-c\s+commit\.gpgsign=false\b/i,
    reason: "Disabling commit.gpgsign via -c is blocked.",
  },
  // --author override on commit
  {
    pattern: /\bgit\s+commit\b.*--author[\s=]/i,
    reason: "git commit --author is blocked. Use your configured identity.",
  },
  // GIT_AUTHOR/COMMITTER env overrides before git commit
  {
    pattern: /\bGIT_AUTHOR_(EMAIL|NAME)=\S*\s+git\s+commit\b/i,
    reason: "GIT_AUTHOR_* env overrides on commit are blocked.",
  },
  {
    pattern: /\bGIT_COMMITTER_(EMAIL|NAME)=\S*\s+git\s+commit\b/i,
    reason: "GIT_COMMITTER_* env overrides on commit are blocked.",
  },
  // -c user.email/user.name overrides on commit
  {
    pattern: /\bgit\s+-c\s+user\.(email|name)=\S*\s+commit\b/i,
    reason: "Overriding user.email/user.name via -c on commit is blocked.",
  },
  // HUSKY=0 bypass
  {
    pattern: /\bHUSKY=0\s+/i,
    reason: "HUSKY=0 is blocked. Husky hooks must run.",
  },
  // SKIP=* bypass
  {
    pattern: /\bSKIP=\S+\s+git\b/i,
    reason: "SKIP= env bypass for git hooks is blocked.",
  },
  // SKIP_PREPARE_COMMIT_MSG / SKIP_PRE_COMMIT bypasses
  {
    pattern: /\bSKIP_(PREPARE_COMMIT_MSG|PRE_COMMIT)=\S+\s+git\b/i,
    reason: "Hook skip env vars are blocked. All hooks must run.",
  },
  // PRE_COMMIT_ALLOW_NO_CONFIG bypass
  {
    pattern: /\bPRE_COMMIT_ALLOW_NO_CONFIG=\S+\s+git\b/i,
    reason: "PRE_COMMIT_ALLOW_NO_CONFIG bypass is blocked.",
  },
  // core.hooksPath manipulation
  {
    pattern: /\bgit\s+-c\s+core\.hooksPath[=\s]/i,
    reason: "Overriding core.hooksPath via -c is blocked.",
  },
  {
    pattern: /\bgit\s+config\s+(--global\s+|--local\s+)?core\.hooksPath\b/i,
    reason: "Changing core.hooksPath is blocked.",
  },
  // jj equivalents
  {
    pattern: /\bjj\s+git\s+push\b.*--no-verify\b/i,
    reason: "jj git push --no-verify is blocked. Pre-push hooks must run.",
  },
];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, _ctx) => {
    if (!isToolCallEventType("bash", event)) return undefined;

    const command = event.input.command;

    for (const rule of DENY_RULES) {
      if (rule.pattern.test(command)) {
        return { block: true, reason: rule.reason };
      }
    }

    return undefined;
  });

  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.notify("🔒 enforce-hooks: hook/signing bypass protection active", "info");
  });
}
