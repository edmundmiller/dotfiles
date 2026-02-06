/**
 * Integration test suite to verify the fix for tool_use/tool_result pairing issues
 *
 * This test simulates the real-world scenario that caused 400 errors before the fix
 */

import { describe, test, expect, beforeAll } from "bun:test";
import { applyPruningWorkflow } from "../src/workflow";
import { registerRule } from "../src/registry";
import { deduplicationRule } from "../src/rules/deduplication";
import { toolPairingRule } from "../src/rules/tool-pairing";
import { recencyRule } from "../src/rules/recency";
import type { DcpConfigWithPruneRuleObjects } from "../src/types";

describe("Fix Verification: Tool Use/Result Pairing", () => {
  beforeAll(() => {
    // Register rules
    registerRule(deduplicationRule);
    registerRule(toolPairingRule);
    registerRule(recencyRule);
  });

  const realWorldMessages = [
    { role: "user", content: "Read the file" },
    {
      role: "assistant",
      content: [
        { type: "text", text: "I'll read it" },
        {
          type: "tool_use",
          id: "toolu_01VzLnitYpwspzkRMSc2bhfA",
          name: "read",
          input: { path: "test.txt" },
        },
      ],
    },
    {
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: "toolu_01VzLnitYpwspzkRMSc2bhfA",
          content: "file contents",
        },
      ],
    },
    { role: "assistant", content: "Got it" },
    { role: "user", content: "Read it again" },
    {
      role: "assistant",
      content: [
        { type: "text", text: "I'll read it" },
        {
          type: "tool_use",
          id: "toolu_01VzLnitYpwspzkRMSc2bhfA",
          name: "read",
          input: { path: "test.txt" },
        },
      ],
    },
    {
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: "toolu_01VzLnitYpwspzkRMSc2bhfA",
          content: "file contents",
        },
      ],
    },
  ] as any;

  const strictConfig: DcpConfigWithPruneRuleObjects = {
    enabled: true,
    debug: false, // Disable debug output in tests
    rules: [deduplicationRule, toolPairingRule, recencyRule],
    keepRecentCount: 0, // Don't protect anything - show pure pruning behavior
  };

  test("should handle duplicate tool calls without breaking pairing", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    // Verify pairing integrity
    const toolUseIds = new Set<string>();

    for (const msg of result) {
      const content = Array.isArray(msg.content) ? msg.content : [];
      const toolUses = content.filter((p: any) => p?.type === "tool_use");

      toolUses.forEach((tu: any) => toolUseIds.add(tu.id));
    }

    for (const msg of result) {
      const content = Array.isArray(msg.content) ? msg.content : [];
      const toolResults = content.filter((p: any) => p?.type === "tool_result");

      for (const tr of toolResults) {
        expect(toolUseIds.has(tr.tool_use_id)).toBe(true);
      }
    }
  });

  test("should prune duplicate messages but maintain at least one valid pair", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    expect(result.length).toBeLessThan(realWorldMessages.length);

    // Should still have at least one tool_use/tool_result pair
    let hasToolUse = false;
    let hasToolResult = false;

    for (const msg of result) {
      const content = Array.isArray(msg.content) ? msg.content : [];

      if (content.some((p: any) => p?.type === "tool_use")) {
        hasToolUse = true;
      }
      if (content.some((p: any) => p?.type === "tool_result")) {
        hasToolResult = true;
      }
    }

    expect(hasToolUse).toBe(true);
    expect(hasToolResult).toBe(true);
  });

  test("should prevent 400 API errors from orphaned tool_results", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    // This test verifies the core fix: no tool_result without corresponding tool_use
    const toolUseIds = new Set<string>();
    const orphanedResults: string[] = [];

    // First pass: collect all tool_use IDs
    for (const msg of result) {
      const content = Array.isArray(msg.content) ? msg.content : [];
      const toolUses = content.filter((p: any) => p?.type === "tool_use");
      toolUses.forEach((tu: any) => toolUseIds.add(tu.id));
    }

    // Second pass: check for orphaned tool_results
    for (const msg of result) {
      const content = Array.isArray(msg.content) ? msg.content : [];
      const toolResults = content.filter((p: any) => p?.type === "tool_result");

      for (const tr of toolResults) {
        if (!toolUseIds.has(tr.tool_use_id)) {
          orphanedResults.push(tr.tool_use_id);
        }
      }
    }

    expect(orphanedResults).toHaveLength(0);
  });

  test("should maintain message flow integrity", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    // Verify basic message structure is maintained
    expect(result.length).toBeGreaterThan(0);

    // All messages should have valid roles
    for (const msg of result) {
      expect(["user", "assistant"]).toContain(msg.role);
    }

    // Should not have completely empty content
    for (const msg of result) {
      if (Array.isArray(msg.content)) {
        expect(msg.content.length).toBeGreaterThan(0);
      } else {
        expect(msg.content).toBeTruthy();
      }
    }
  });

  test("should handle the specific error scenario from the real bug report", () => {
    // This is the exact scenario that caused the 400 error
    const problematicMessages = [
      { role: "user", content: "Read the file" },
      {
        role: "assistant",
        content: [
          { type: "text", text: "I'll read it" },
          { type: "tool_use", id: "toolu_ABC", name: "read", input: { path: "test.txt" } },
        ],
      },
      {
        role: "user",
        content: [{ type: "tool_result", tool_use_id: "toolu_ABC", content: "content" }],
      },
      // Duplicate that could cause orphaned result
      {
        role: "assistant",
        content: [
          { type: "text", text: "I'll read it" },
          { type: "tool_use", id: "toolu_ABC", name: "read", input: { path: "test.txt" } },
        ],
      },
      {
        role: "user",
        content: [{ type: "tool_result", tool_use_id: "toolu_ABC", content: "content" }],
      },
    ] as any;

    // This should not throw and should maintain pairing
    const result = applyPruningWorkflow(problematicMessages, strictConfig);

    const toolUseIds = new Set<string>();
    let allPairsValid = true;

    // Collect tool_use IDs
    for (const msg of result) {
      const content = Array.isArray(msg.content) ? msg.content : [];
      content.forEach((part: any) => {
        if (part?.type === "tool_use") {
          toolUseIds.add(part.id);
        }
      });
    }

    // Verify all tool_results have matching tool_use
    for (const msg of result) {
      const content = Array.isArray(msg.content) ? msg.content : [];
      content.forEach((part: any) => {
        if (part?.type === "tool_result") {
          if (!toolUseIds.has(part.tool_use_id)) {
            allPairsValid = false;
          }
        }
      });
    }

    expect(allPairsValid).toBe(true);
  });
});
