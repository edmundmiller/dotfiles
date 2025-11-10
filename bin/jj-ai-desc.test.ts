import { describe, it, expect, beforeEach, mock } from "bun:test";
import { stripMarkdownFences, parseArgs } from "./jj-ai-desc-testable";

describe("jj-ai-desc unit tests", () => {
  describe("stripMarkdownFences", () => {
    it("should strip markdown fences with language identifier", () => {
      const input = "```typescript\nfeat: add feature\n```";
      const expected = "feat: add feature";
      expect(stripMarkdownFences(input)).toBe(expected);
    });

    it("should strip markdown fences without language identifier", () => {
      const input = "```\nfix: bug fix\n```";
      const expected = "fix: bug fix";
      expect(stripMarkdownFences(input)).toBe(expected);
    });

    it("should strip multiple markdown fence blocks", () => {
      const input = "```\nfeat: first\n```\nSome text\n```\nfeat: second\n```";
      const expected = "feat: first\nSome text\nfeat: second";
      expect(stripMarkdownFences(input)).toBe(expected);
    });

    it("should handle markdown fences at start of string", () => {
      const input = "```\nchore: update\n```";
      const expected = "chore: update";
      expect(stripMarkdownFences(input)).toBe(expected);
    });

    it("should handle markdown fences at end of string", () => {
      const input = "Some text\n```\nrefactor: cleanup\n```";
      const expected = "Some text\nrefactor: cleanup";
      expect(stripMarkdownFences(input)).toBe(expected);
    });

    it("should handle text without markdown fences", () => {
      const input = "feat: no fences here";
      expect(stripMarkdownFences(input)).toBe(input);
    });

    it("should handle empty string", () => {
      expect(stripMarkdownFences("")).toBe("");
    });

    it("should handle fence with trailing newline", () => {
      const input = "```\nfix: something\n```\n";
      const expected = "fix: something";
      expect(stripMarkdownFences(input)).toBe(expected);
    });

    it("should handle fence with multiple languages", () => {
      const input = "```bash\nfix: first\n```\n```typescript\nfeat: second\n```";
      const expected = "fix: first\nfeat: second";
      expect(stripMarkdownFences(input)).toBe(expected);
    });

    it("should handle incomplete fences gracefully", () => {
      const input = "```\nfeat: incomplete";
      // Should still try to strip what it can
      const result = stripMarkdownFences(input);
      expect(result).not.toContain("```");
    });
  });

  describe("parseArgs", () => {
    it("should parse no arguments with defaults", () => {
      const args = parseArgs([]);
      expect(args.revision).toBe("@");
      expect(args.edit).toBe(false);
      expect(args.help).toBe(false);
    });

    it("should parse --revision flag", () => {
      const args = parseArgs(["--revision", "@-"]);
      expect(args.revision).toBe("@-");
      expect(args.edit).toBe(false);
    });

    it("should parse -r short flag", () => {
      const args = parseArgs(["-r", "main"]);
      expect(args.revision).toBe("main");
    });

    it("should parse --edit flag", () => {
      const args = parseArgs(["--edit"]);
      expect(args.edit).toBe(true);
    });

    it("should parse -e short flag", () => {
      const args = parseArgs(["-e"]);
      expect(args.edit).toBe(true);
    });

    it("should parse --help flag", () => {
      const args = parseArgs(["--help"]);
      expect(args.help).toBe(true);
    });

    it("should parse -h short flag", () => {
      const args = parseArgs(["-h"]);
      expect(args.help).toBe(true);
    });

    it("should parse combined flags", () => {
      const args = parseArgs(["-r", "HEAD", "--edit"]);
      expect(args.revision).toBe("HEAD");
      expect(args.edit).toBe(true);
    });

    it("should handle revision without value", () => {
      const args = parseArgs(["-r"]);
      // Should default to @ when no value provided
      expect(args.revision).toBe("@");
    });

    it("should parse flags in any order", () => {
      const args1 = parseArgs(["--edit", "-r", "main"]);
      const args2 = parseArgs(["-r", "main", "--edit"]);
      expect(args1).toEqual(args2);
    });
  });

  describe("Conventional commit message validation", () => {
    const validPrefixes = ["feat", "fix", "refactor", "docs", "test", "chore", "style", "perf"];

    validPrefixes.forEach((prefix) => {
      it(`should accept ${prefix} prefix`, () => {
        const message = `${prefix}: some change`;
        const cleaned = stripMarkdownFences(`\`\`\`\n${message}\n\`\`\``);
        expect(cleaned).toBe(message);
        expect(cleaned).toMatch(new RegExp(`^${prefix}:`));
      });
    });

    it("should handle scope in conventional commits", () => {
      const message = "feat(api): add new endpoint";
      const cleaned = stripMarkdownFences(`\`\`\`\n${message}\n\`\`\``);
      expect(cleaned).toBe(message);
      expect(cleaned).toMatch(/^feat\([^)]+\):/);
    });

    it("should handle breaking change indicator", () => {
      const message = "feat!: breaking change";
      const cleaned = stripMarkdownFences(`\`\`\`\n${message}\n\`\`\``);
      expect(cleaned).toBe(message);
      expect(cleaned).toMatch(/^feat!:/);
    });
  });

  describe("Edge cases and error scenarios", () => {
    it("should handle very long commit messages", () => {
      const longMessage = "feat: " + "a".repeat(200);
      const input = `\`\`\`\n${longMessage}\n\`\`\``;
      const cleaned = stripMarkdownFences(input);
      expect(cleaned).toBe(longMessage);
      expect(cleaned.length).toBeGreaterThan(72); // Over recommended limit
    });

    it("should handle commit messages with special characters", () => {
      const message = 'fix: handle "quotes" and (parentheses) & ampersands';
      const input = `\`\`\`\n${message}\n\`\`\``;
      expect(stripMarkdownFences(input)).toBe(message);
    });

    it("should handle commit messages with unicode", () => {
      const message = "feat: add 🎉 emoji support";
      const input = `\`\`\`\n${message}\n\`\`\``;
      expect(stripMarkdownFences(input)).toBe(message);
    });

    it("should handle multi-line commit messages", () => {
      const message = "feat: add feature\n\nThis adds a new feature\nwith multiple lines";
      const input = `\`\`\`\n${message}\n\`\`\``;
      const cleaned = stripMarkdownFences(input);
      expect(cleaned).toContain("feat: add feature");
      expect(cleaned).toContain("This adds a new feature");
    });

    it("should handle commit message with code in body", () => {
      const message = "fix: update logic\n\nChanged `if (x)` to `if (y)`";
      const input = `\`\`\`\n${message}\n\`\`\``;
      const cleaned = stripMarkdownFences(input);
      expect(cleaned).toContain("fix: update logic");
      expect(cleaned).toContain("`if (x)`");
    });
  });

  describe("Claude output format handling", () => {
    it("should handle Claude wrapping output in code fence", () => {
      const actualMessage = "feat: add AI commit message generation";
      const claudeOutput = `\`\`\`\n${actualMessage}\n\`\`\``;
      expect(stripMarkdownFences(claudeOutput)).toBe(actualMessage);
    });

    it("should handle Claude adding language identifier", () => {
      const actualMessage = "refactor: extract AI commit generation to script";
      const claudeOutput = `\`\`\`text\n${actualMessage}\n\`\`\``;
      expect(stripMarkdownFences(claudeOutput)).toBe(actualMessage);
    });

    it("should handle Claude output with extra whitespace", () => {
      const actualMessage = "chore: update dependencies";
      const claudeOutput = `\`\`\`\n  ${actualMessage}  \n\`\`\``;
      const cleaned = stripMarkdownFences(claudeOutput).trim();
      expect(cleaned).toBe(actualMessage);
    });

    it("should handle plain text output from Claude", () => {
      const message = "docs: update README";
      expect(stripMarkdownFences(message)).toBe(message);
    });
  });

  describe("Real-world scenarios", () => {
    it("should handle typical feat commit", () => {
      const claudeOutput = `\`\`\`
feat: add jjui keybindings for AI commit generation
\`\`\``;
      const cleaned = stripMarkdownFences(claudeOutput);
      expect(cleaned).toBe("feat: add jjui keybindings for AI commit generation");
      expect(cleaned.length).toBeLessThanOrEqual(72);
    });

    it("should handle typical fix commit", () => {
      const claudeOutput = `\`\`\`
fix: strip markdown fences from Claude output
\`\`\``;
      const cleaned = stripMarkdownFences(claudeOutput);
      expect(cleaned).toBe("fix: strip markdown fences from Claude output");
    });

    it("should handle typical refactor commit", () => {
      const claudeOutput = `\`\`\`typescript
refactor: replace Python script with Bun TypeScript version
\`\`\``;
      const cleaned = stripMarkdownFences(claudeOutput);
      expect(cleaned).toBe("refactor: replace Python script with Bun TypeScript version");
    });

    it("should handle chore commit", () => {
      const claudeOutput = `chore: update jj config to point to new script`;
      const cleaned = stripMarkdownFences(claudeOutput);
      expect(cleaned).toBe("chore: update jj config to point to new script");
    });
  });

  describe("72 character limit awareness", () => {
    it("should handle commits at exactly 72 chars", () => {
      // 72 characters including "feat: "
      const message = "feat: " + "x".repeat(66); // 6 + 66 = 72
      expect(message.length).toBe(72);
      const cleaned = stripMarkdownFences(`\`\`\`\n${message}\n\`\`\``);
      expect(cleaned.length).toBe(72);
    });

    it("should handle commits under 72 chars", () => {
      const message = "feat: short message";
      expect(message.length).toBeLessThan(72);
      const cleaned = stripMarkdownFences(`\`\`\`\n${message}\n\`\`\``);
      expect(cleaned.length).toBeLessThan(72);
    });

    it("should not enforce 72 char limit (just strip fences)", () => {
      const longMessage = "feat: " + "x".repeat(100);
      expect(longMessage.length).toBeGreaterThan(72);
      const cleaned = stripMarkdownFences(`\`\`\`\n${longMessage}\n\`\`\``);
      expect(cleaned).toBe(longMessage); // Still accepts long messages
    });
  });

  describe("Argument parsing edge cases", () => {
    it("should handle empty revision after flag", () => {
      const args = parseArgs(["-r", ""]);
      // Empty string should default to "@" (safer behavior)
      expect(args.revision).toBe("@");
    });

    it("should handle multiple --edit flags", () => {
      const args = parseArgs(["--edit", "--edit"]);
      expect(args.edit).toBe(true);
    });

    it("should handle unknown flags gracefully", () => {
      const args = parseArgs(["--unknown", "value"]);
      // Should still return valid defaults
      expect(args.revision).toBe("@");
      expect(args.edit).toBe(false);
    });

    it("should preserve last revision when specified multiple times", () => {
      const args = parseArgs(["-r", "first", "-r", "second"]);
      expect(args.revision).toBe("second");
    });
  });
});

describe("Integration scenarios", () => {
  describe("Full pipeline simulation", () => {
    it("should process a typical commit flow", () => {
      // Simulate the full flow:
      // 1. Parse args
      const args = parseArgs([]);

      // 2. Simulate Claude output with fences
      const claudeOutput = `\`\`\`
feat: add AI-powered commit message generation
\`\`\``;

      // 3. Clean the output
      const cleanedMessage = stripMarkdownFences(claudeOutput);

      // 4. Verify result
      expect(args.revision).toBe("@");
      expect(cleanedMessage).toBe("feat: add AI-powered commit message generation");
      expect(cleanedMessage).toMatch(/^feat:/);
      expect(cleanedMessage.length).toBeLessThanOrEqual(72);
    });

    it("should handle edit mode flow", () => {
      const args = parseArgs(["--edit"]);
      const claudeOutput = `\`\`\`\nrefactor: improve error handling\n\`\`\``;
      const cleaned = stripMarkdownFences(claudeOutput);

      expect(args.edit).toBe(true);
      expect(cleaned).toBe("refactor: improve error handling");
    });

    it("should handle custom revision flow", () => {
      const args = parseArgs(["-r", "@-"]);
      const claudeOutput = `fix: correct typo in previous commit`;
      const cleaned = stripMarkdownFences(claudeOutput);

      expect(args.revision).toBe("@-");
      expect(cleaned).toBe("fix: correct typo in previous commit");
    });
  });

  describe("Error recovery scenarios", () => {
    it("should handle Claude returning empty string", () => {
      const claudeOutput = `\`\`\`\n\n\`\`\``;
      const cleaned = stripMarkdownFences(claudeOutput);
      expect(cleaned).toBe("");
    });

    it("should handle Claude returning only whitespace", () => {
      const claudeOutput = `\`\`\`\n   \n\`\`\``;
      const cleaned = stripMarkdownFences(claudeOutput).trim();
      expect(cleaned).toBe("");
    });

    it("should handle malformed markdown fences", () => {
      const message = "feat: test";
      const malformed = `\`\`${message}\`\``; // Only 2 backticks
      // Should not crash, just return as-is or partially cleaned
      expect(() => stripMarkdownFences(malformed)).not.toThrow();
    });
  });
});
