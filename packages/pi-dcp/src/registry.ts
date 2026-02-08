/**
 * Rule registry system
 */

import type { PruneRule } from "./types";
import { getLogger } from "./logger";

/**
 * Global registry of available pruning rules
 */
const ruleRegistry = new Map<string, PruneRule>();

/**
 * Register a pruning rule
 */
export function registerRule(rule: PruneRule): void {
  // Validate rule has required fields
  if (!rule.name) {
    throw new Error("Rule must have a name");
  }

  if (!rule.prepare && !rule.process) {
    throw new Error(`Rule "${rule.name}" must have at least one of: prepare, process`);
  }

  // Warn if duplicate (but allow override)
  if (ruleRegistry.has(rule.name)) {
    getLogger().warn(`Overriding existing rule: ${rule.name}`);
  }

  ruleRegistry.set(rule.name, rule);
}

/**
 * Get rule by name
 */
export function getRule(name: string): PruneRule | undefined {
  return ruleRegistry.get(name);
}

/**
 * Resolve rule reference (string name or inline object)
 */
export function resolveRule(ruleRef: string | PruneRule): PruneRule {
  // If already an object, validate and return
  if (typeof ruleRef === "object") {
    if (!ruleRef.name) {
      throw new Error("Inline rule must have a name");
    }
    if (!ruleRef.prepare && !ruleRef.process) {
      throw new Error(`Inline rule "${ruleRef.name}" must have at least one of: prepare, process`);
    }
    return ruleRef;
  }

  // String reference - lookup in registry
  const rule = ruleRegistry.get(ruleRef);
  if (!rule) {
    throw new Error(
      `Rule not found: ${ruleRef}. Available rules: ${Array.from(ruleRegistry.keys()).join(", ")}`
    );
  }

  return rule;
}

/**
 * Get all registered rules
 */
export function getAllRules(): PruneRule[] {
  return Array.from(ruleRegistry.values());
}

/**
 * Get all registered rule names
 */
export function getRuleNames(): string[] {
  return Array.from(ruleRegistry.keys());
}
