import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { matchesKey, visibleWidth } from "@mariozechner/pi-tui";
import { createConfigService } from "@zenobius/pi-extension-config";
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import * as path from "node:path";

interface GenerateCommitMessageConfig {
  mode?: string;
  prompt?: string;
  /** Maximum output cost per million tokens (default: 1.0) */
  maxOutputCost?: number;
}

interface ModelInfo {
  id: string;
  provider: string;
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
}

const USER_AGENTS_DIR = path.join(homedir(), ".pi", "agent", "agents");
const CONFIG_NAME = "generate-commit-message";

const DEFAULT_PROMPT = "Write and stage commits according to the writing-git-commits skill";
const DEFAULT_SKILL = "writing-git-commits";
const DEFAULT_AGENT_CANDIDATES = ["general", "worker", "default", "scout"] as const;

/** Maximum output cost per million tokens for "cheap" models */
const DEFAULT_MAX_OUTPUT_COST = 1.0;

/** Hard fallback if no models are available at all */
const HARD_FALLBACK_MODEL = "github-copilot/gpt-4o-mini";

const FALLBACK_AGENT_NAME = "commit-writer";

const FALLBACK_AGENT_CONTENT = `---
name: ${FALLBACK_AGENT_NAME}
description: Focused subagent for writing and staging git commits
tools: read, bash
skills: writing-git-commits
---

Create and stage clean, atomic, conventional commits for the current repository.
Use the writing-git-commits skill and keep commits scoped, descriptive, and safe.
`;

/** Default configuration values */
const DEFAULT_CONFIG: GenerateCommitMessageConfig = {
  prompt: DEFAULT_PROMPT,
  maxOutputCost: DEFAULT_MAX_OUTPUT_COST,
};

function normalizeMode(mode?: string): string | undefined {
  if (!mode) return undefined;
  const trimmed = mode.trim();
  if (!trimmed) return undefined;
  return /^[^/\s]+\/[^\s]+$/.test(trimmed) ? trimmed : undefined;
}

/**
 * Calculate a combined cost score for a model.
 * Weights output cost more heavily since commit messages have short input but longer output.
 */
/**
 * Calculate cost score for model comparison.
 * Higher score = more expensive.
 * Models with $0/$0 pricing (GitHub Copilot, request-based) get penalized
 * to deprioritize them in favor of token-based models where costs are clear.
 */
function calculateCostScore(model: ModelInfo): number {
  const { input, output } = model.cost;

  // Deprioritize request-based pricing models (GitHub Copilot shows $0/$0)
  // These don't fit the token-cost model and should only be selected if
  // no token-based options exist
  if (input === 0 && output === 0) {
    return Number.MAX_SAFE_INTEGER;
  }

  return input + output * 2;
}

/**
 * Check if a model name suggests it's a cheap/lite variant.
 */
function isCheapModelName(id: string): boolean {
  return /(mini|flash|nano|haiku|lite|micro|free)/i.test(id);
}

interface ModelSelection {
  model: string;
  source: "config" | "auto";
  cost: ModelInfo["cost"] | null;
}

/**
 * Pick the cheapest available model based on actual pricing data.
 * Falls back to name-based heuristics if cost data is unavailable.
 *
 * Note: Request-based pricing models (GitHub Copilot: $0/$0) are deprioritized
 * in favor of token-based models where costs are transparent and comparable.
 */
async function pickCheapestModel(
  ctx: ExtensionContext,
  maxOutputCost: number = DEFAULT_MAX_OUTPUT_COST
): Promise<ModelSelection> {
  const available = (await ctx.modelRegistry.getAvailable()) as ModelInfo[];

  if (available.length === 0) {
    return { model: HARD_FALLBACK_MODEL, source: "auto", cost: null };
  }

  // First, try to find token-based models (not $0/$0) under the cost threshold
  const tokenBased = available.filter((m) => !(m.cost.input === 0 && m.cost.output === 0));

  const cheapModels = tokenBased
    .filter((m) => m.cost.output <= maxOutputCost)
    .sort((a, b) => calculateCostScore(a) - calculateCostScore(b));

  if (cheapModels.length > 0) {
    const best = cheapModels[0];
    return {
      model: `${best.provider}/${best.id}`,
      source: "auto",
      cost: best.cost,
    };
  }

  // If no token-based models under threshold, look for "cheap-sounding" names
  const cheapNamed = tokenBased
    .filter((m) => isCheapModelName(m.id))
    .sort((a, b) => calculateCostScore(a) - calculateCostScore(b));

  if (cheapNamed.length > 0) {
    const best = cheapNamed[0];
    return {
      model: `${best.provider}/${best.id}`,
      source: "auto",
      cost: best.cost,
    };
  }

  // If no token-based models at all, use the cheapest token-based overall
  if (tokenBased.length > 0) {
    const sorted = [...tokenBased].sort((a, b) => calculateCostScore(a) - calculateCostScore(b));
    const best = sorted[0];
    return {
      model: `${best.provider}/${best.id}`,
      source: "auto",
      cost: best.cost,
    };
  }

  // Last resort: use request-based models (GitHub Copilot, etc.)
  const sorted = [...available].sort((a, b) => calculateCostScore(a) - calculateCostScore(b));
  const best = sorted[0];
  return {
    model: `${best.provider}/${best.id}`,
    source: "auto",
    cost: best.cost,
  };
}

/**
 * Look up cost info for a configured model.
 */
async function getModelCost(
  ctx: ExtensionContext,
  modelString: string
): Promise<ModelInfo["cost"] | null> {
  const [provider, ...idParts] = modelString.split("/");
  const modelId = idParts.join("/");
  const available = (await ctx.modelRegistry.getAvailable()) as ModelInfo[];
  const found = available.find((m) => m.provider === provider && m.id === modelId);
  return found?.cost ?? null;
}

/**
 * Format cost for display.
 * Shows input/output cost per million tokens with appropriate precision.
 * Avoids rounding up small values (e.g., $0.0375 → $0.0375, not $0.04).
 */
function formatCost(cost: ModelInfo["cost"] | null): string {
  if (!cost) return "unknown pricing";

  const formatPrice = (price: number): string => {
    if (price === 0) return "0";

    // Convert to string and count significant decimals
    const str = price.toString();

    // For very small prices, preserve more decimals
    if (price < 0.001) {
      return price.toFixed(5).replace(/0+$/, "");
    } else if (price < 0.01) {
      // Show up to 4 decimals, remove trailing zeros
      return price.toFixed(4).replace(/0+$/, "");
    } else if (price < 1) {
      // Show up to 3 decimals
      return price.toFixed(3).replace(/0+$/, "");
    } else {
      // For >= $1, use 2 decimals
      return price
        .toFixed(2)
        .replace(/\.?0+$/, "")
        .replace(/^(\d+)$/, "$1.00");
    }
  };

  return `$${formatPrice(cost.input)}/$${formatPrice(cost.output)} per 1M tokens (in/out)`;
}

function stripQuotes(value: string): string {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

function getAgentNameFromFile(filePath: string): string | null {
  try {
    const content = readFileSync(filePath, "utf-8");
    const frontmatter = content.match(/^---\n([\s\S]*?)\n---/);
    if (!frontmatter) {
      return path.basename(filePath, ".md");
    }
    const nameMatch = frontmatter[1].match(/^name:\s*(.+)$/m);
    if (!nameMatch) {
      return path.basename(filePath, ".md");
    }
    return stripQuotes(nameMatch[1]);
  } catch {
    return null;
  }
}

function listAgentNamesInDir(dir: string): string[] {
  if (!existsSync(dir)) return [];
  const names: string[] = [];

  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isFile() && !entry.isSymbolicLink()) continue;
    if (!entry.name.endsWith(".md")) continue;
    if (entry.name.endsWith(".chain.md")) continue;

    const fullPath = path.join(dir, entry.name);
    const agentName = getAgentNameFromFile(fullPath);
    if (!agentName) continue;
    names.push(agentName);
  }

  return names;
}

function findNearestProjectAgentsDir(cwd: string): string | null {
  let current = cwd;

  while (true) {
    const candidate = path.join(current, ".pi", "agents");
    if (existsSync(candidate)) return candidate;

    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function ensureFallbackAgent(): string {
  if (!existsSync(USER_AGENTS_DIR)) {
    mkdirSync(USER_AGENTS_DIR, { recursive: true });
  }

  const fallbackPath = path.join(USER_AGENTS_DIR, `${FALLBACK_AGENT_NAME}.md`);
  if (!existsSync(fallbackPath)) {
    writeFileSync(fallbackPath, FALLBACK_AGENT_CONTENT, "utf-8");
  }

  return FALLBACK_AGENT_NAME;
}

function chooseAgent(cwd: string): string {
  const projectDir = findNearestProjectAgentsDir(cwd);
  const projectAgents = projectDir ? listAgentNamesInDir(projectDir) : [];
  const userAgents = listAgentNamesInDir(USER_AGENTS_DIR);
  const all = [...projectAgents, ...userAgents];

  for (const preferred of DEFAULT_AGENT_CANDIDATES) {
    if (all.includes(preferred)) return preferred;
  }

  if (all.length > 0) return all[0];
  return ensureFallbackAgent();
}

function buildPrompt(config: GenerateCommitMessageConfig, args: string): string {
  const argPrompt = args.trim();
  if (argPrompt) return argPrompt;

  const configPrompt = config.prompt?.trim();
  if (configPrompt) return configPrompt;

  return DEFAULT_PROMPT;
}

/** Picker item types for grouped model list */
type PickerItem =
  | { type: "separator"; label: string }
  | { type: "model"; modelId: string; modelName: string; costLabel: string; model: ModelInfo };

/**
 * Display a formatted model selection widget with colors, alignment, and sorting.
 * Models are grouped by provider with separator headers.
 * Returns the selected model ID or null if cancelled.
 */
async function selectModelInteractive(ctx: ExtensionContext): Promise<string | null> {
  if (!ctx.hasUI) {
    return null; // Cannot show UI
  }

  const available = (await ctx.modelRegistry.getAvailable()) as ModelInfo[];

  if (available.length === 0) {
    ctx.ui.notify("No models available", "error");
    return null;
  }

  // We'll use custom UI to render a nicely formatted model picker
  const result = await ctx.ui.custom<string | null>(
    (tui, theme, _keybindings, done) => {
      let selectedIndex = 0;
      let sortBy: "name" | "provider" | "cost" = "provider";
      let sortAsc = true;
      let filterQuery = "";

      // Fuzzy filter function
      const fuzzyMatch = (text: string, query: string): boolean => {
        let queryIdx = 0;
        for (let i = 0; i < text.length && queryIdx < query.length; i++) {
          if (text[i].toLowerCase() === query[queryIdx].toLowerCase()) {
            queryIdx++;
          }
        }
        return queryIdx === query.length;
      };

      // Group models by provider
      const groupByProvider = (models: ModelInfo[]): Map<string, ModelInfo[]> => {
        const groups = new Map<string, ModelInfo[]>();
        for (const model of models) {
          const existing = groups.get(model.provider) || [];
          existing.push(model);
          groups.set(model.provider, existing);
        }
        return groups;
      };

      // Build picker items with separators
      const buildPickerItems = (): PickerItem[] => {
        // First filter models
        let filtered = available;
        if (filterQuery) {
          filtered = available.filter((m) => fuzzyMatch(`${m.provider}/${m.id}`, filterQuery));
        }

        // Sort models
        const sorted = [...filtered].sort((a, b) => {
          let cmp = 0;
          if (sortBy === "name") {
            cmp = a.id.localeCompare(b.id);
          } else if (sortBy === "provider") {
            const providerCmp = a.provider.localeCompare(b.provider);
            if (providerCmp !== 0) cmp = providerCmp;
            else cmp = a.id.localeCompare(b.id);
          } else if (sortBy === "cost") {
            cmp = a.cost.input - b.cost.input;
          }
          return sortAsc ? cmp : -cmp;
        });

        // Group by provider
        const groups = groupByProvider(sorted);
        const items: PickerItem[] = [];

        // Sort provider names
        const providers = [...groups.keys()].sort((a, b) =>
          sortAsc ? a.localeCompare(b) : b.localeCompare(a)
        );

        for (const provider of providers) {
          const models = groups.get(provider)!;
          items.push({ type: "separator", label: provider });
          for (const model of models) {
            items.push({
              type: "model",
              modelId: `${model.provider}/${model.id}`,
              modelName: model.id,
              costLabel: formatCost(model.cost),
              model,
            });
          }
        }

        return items;
      };

      // Find next selectable index (skip separators)
      const nextSelectableIndex = (
        items: PickerItem[],
        current: number,
        direction: 1 | -1
      ): number => {
        let next = current + direction;
        // Wrap around
        if (next < 0) next = items.length - 1;
        if (next >= items.length) next = 0;

        // Skip separators
        const startNext = next;
        while (items[next]?.type === "separator") {
          next += direction;
          if (next < 0) next = items.length - 1;
          if (next >= items.length) next = 0;
          // Prevent infinite loop if all items are separators
          if (next === startNext) break;
        }
        return next;
      };

      // Find first selectable index
      const findFirstSelectable = (items: PickerItem[]): number => {
        for (let i = 0; i < items.length; i++) {
          if (items[i].type === "model") return i;
        }
        return 0;
      };

      class ModelSelector {
        render(width: number): string[] {
          const lines: string[] = [];
          const items = buildPickerItems();

          // Helper: pad text to exact length, handling ANSI codes
          const pad = (s: string, len: number): string => {
            const vis = visibleWidth(s);
            return s + " ".repeat(Math.max(0, len - vis));
          };

          // Helper: render border row with content on sides
          const row = (content: string): string => {
            const innerW = width - 2;
            return theme.fg("border", "│") + pad(content, innerW) + theme.fg("border", "│");
          };

          // Helper: render centered header with rounded corners
          const renderHeader = (text: string): string => {
            const innerW = width - 2;
            const padLen = Math.max(0, innerW - visibleWidth(text));
            const padLeft = Math.floor(padLen / 2);
            const padRight = padLen - padLeft;
            return (
              theme.fg("border", "╭" + "─".repeat(padLeft)) +
              theme.fg("accent", text) +
              theme.fg("border", "─".repeat(padRight) + "╮")
            );
          };

          // Helper: render centered footer with rounded corners
          const renderFooter = (text: string): string => {
            const innerW = width - 2;
            const padLen = Math.max(0, innerW - visibleWidth(text));
            const padLeft = Math.floor(padLen / 2);
            const padRight = padLen - padLeft;
            return (
              theme.fg("border", "╰" + "─".repeat(padLeft)) +
              theme.fg("dim", text) +
              theme.fg("border", "─".repeat(padRight) + "╯")
            );
          };

          // Helper: render separator line
          const renderSeparator = (label: string): string => {
            const innerW = width - 2;
            const prefix = `── ${label} `;
            const prefixLen = visibleWidth(prefix);
            const dashCount = Math.max(0, innerW - prefixLen - 1);
            return (
              theme.fg("border", "│") +
              " " +
              theme.fg("dim", prefix + "─".repeat(dashCount)) +
              theme.fg("border", "│")
            );
          };

          // Top spacing
          lines.push("");

          // Header with sort status
          const sortLabel = `${sortBy}${sortAsc ? " ↑" : " ↓"}`;
          const headerText = `Select a model for commit generation [${sortLabel}]`;
          lines.push(renderHeader(headerText));

          // Filter input line
          const filterDisplay = filterQuery || theme.fg("muted", "(type to filter)");
          lines.push(row(" " + theme.fg("accent", ">") + " " + filterDisplay));

          lines.push(row(""));

          // Count actual model items for "no models" check
          const modelItems = items.filter((i) => i.type === "model");

          if (modelItems.length === 0) {
            lines.push(row(" " + theme.fg("muted", "No models matching filter")));
          } else {
            // Find max model name length for alignment (just the model name, not full ID)
            const maxModelNameLen = Math.max(
              ...modelItems.map(
                (i) => (i as Extract<PickerItem, { type: "model" }>).modelName.length
              )
            );

            // Render items
            for (let i = 0; i < items.length; i++) {
              const item = items[i];

              if (item.type === "separator") {
                lines.push(renderSeparator(item.label));
              } else {
                const isSelected = i === selectedIndex;
                const modelPart = item.modelName;
                const costPart = item.costLabel;

                if (isSelected) {
                  // For selected items, construct content first, then highlight
                  const modelPadded = modelPart.padEnd(maxModelNameLen);
                  const innerW = width - 2;
                  const contentWidth = visibleWidth(" ▶ " + modelPadded + "  " + costPart);
                  const spacing = " ".repeat(Math.max(0, innerW - contentWidth));
                  const itemContent =
                    " ▶ " +
                    theme.fg("text", modelPadded) +
                    "  " +
                    spacing +
                    theme.fg("muted", costPart);
                  lines.push(
                    theme.fg("border", "│") +
                      theme.bg("userMessageBg", pad(itemContent, innerW)) +
                      theme.fg("border", "│")
                  );
                } else {
                  // For unselected items, build with separate colors and spacing
                  const modelPadded = modelPart.padEnd(maxModelNameLen);
                  const innerW = width - 2;
                  const contentWidth = visibleWidth("   " + modelPadded + "  " + costPart);
                  const spacing = " ".repeat(Math.max(0, innerW - contentWidth));
                  const itemContent =
                    "   " +
                    theme.fg("text", modelPadded) +
                    "  " +
                    spacing +
                    theme.fg("muted", costPart);
                  lines.push(
                    theme.fg("border", "│") + pad(itemContent, innerW) + theme.fg("border", "│")
                  );
                }
              }
            }
          }

          // Preview footer for selected model
          const selectedItem = items[selectedIndex];
          if (selectedItem?.type === "model") {
            lines.push(row(""));
            lines.push(row(" " + theme.fg("accent", selectedItem.modelId)));
            lines.push(row(" " + theme.fg("muted", selectedItem.costLabel)));
          }

          // Footer with instructions
          lines.push(row(""));
          const instructions =
            "↑/↓ Navigate  Enter/Space Select  n/p/c Sort  Backspace Clear  Esc/Ctrl+C Cancel";
          const instDisplay =
            instructions.length > width - 4
              ? instructions.substring(0, width - 7) + "..."
              : instructions;
          lines.push(renderFooter(instDisplay));

          // Bottom spacing
          lines.push("");

          return lines;
        }

        handleInput(data: string): void {
          const items = buildPickerItems();

          // Handle Escape or Ctrl+C to cancel (using matchesKey for cross-terminal compatibility)
          if (matchesKey(data, "escape") || matchesKey(data, "ctrl+c")) {
            done(null);
            return;
          }

          // Handle arrow keys or vim navigation (skip separators)
          if (matchesKey(data, "up") || data === "k") {
            selectedIndex = nextSelectableIndex(items, selectedIndex, -1);
            return;
          } else if (matchesKey(data, "down") || data === "j") {
            selectedIndex = nextSelectableIndex(items, selectedIndex, 1);
            return;
          }

          // Handle backspace to clear filter
          if (matchesKey(data, "backspace")) {
            filterQuery = filterQuery.slice(0, -1);
            const newItems = buildPickerItems();
            selectedIndex = findFirstSelectable(newItems);
            return;
          }

          // Handle regular characters for filtering
          if (data.length === 1 && /[a-zA-Z0-9\-_/.]/.test(data)) {
            filterQuery += data;
            const newItems = buildPickerItems();
            selectedIndex = findFirstSelectable(newItems);
            return;
          }

          if (matchesKey(data, "enter") || matchesKey(data, "space")) {
            // Enter or Space - select current model
            const item = items[selectedIndex];
            if (item?.type === "model") {
              done(item.modelId);
            }
          } else if (data.toLowerCase() === "n") {
            // Sort by name
            if (sortBy === "name") {
              sortAsc = !sortAsc;
            } else {
              sortBy = "name";
              sortAsc = true;
            }
            const newItems = buildPickerItems();
            selectedIndex = findFirstSelectable(newItems);
          } else if (data.toLowerCase() === "p") {
            // Sort by provider
            if (sortBy === "provider") {
              sortAsc = !sortAsc;
            } else {
              sortBy = "provider";
              sortAsc = true;
            }
            const newItems = buildPickerItems();
            selectedIndex = findFirstSelectable(newItems);
          } else if (data.toLowerCase() === "c") {
            // Sort by cost
            if (sortBy === "cost") {
              sortAsc = !sortAsc;
            } else {
              sortBy = "cost";
              sortAsc = true;
            }
            const newItems = buildPickerItems();
            selectedIndex = findFirstSelectable(newItems);
          }
        }

        invalidate(): void {
          // No cached state
        }
      }

      return new ModelSelector();
    },
    { overlay: true, overlayOptions: { width: "100%" } }
  );

  return result || null;
}

async function runGenerateCommit(
  args: string,
  ctx: ExtensionContext,
  pi: ExtensionAPI,
  explicitModel?: string
): Promise<void> {
  const configService = await createConfigService<GenerateCommitMessageConfig>(CONFIG_NAME, {
    defaults: DEFAULT_CONFIG,
  });
  const config = configService.config;
  const maxCost = config.maxOutputCost ?? DEFAULT_MAX_OUTPUT_COST;

  // Determine model selection
  let selection: ModelSelection;

  // Priority: explicit model > configured model > auto-select
  if (explicitModel) {
    const cost = await getModelCost(ctx, explicitModel);
    selection = { model: explicitModel, source: "config", cost };
  } else {
    const configuredMode = normalizeMode(config.mode);
    if (configuredMode) {
      const cost = await getModelCost(ctx, configuredMode);
      selection = { model: configuredMode, source: "config", cost };
    } else {
      selection = await pickCheapestModel(ctx, maxCost);
    }
  }

  const prompt = buildPrompt(config, args);
  const agent = chooseAgent(ctx.cwd);

  const payload = {
    agent,
    task: prompt,
    model: selection.model,
    skill: DEFAULT_SKILL,
    clarify: false,
    agentScope: "both",
  };

  // Provide user feedback
  if (ctx.hasUI) {
    const sourceLabel = selection.source === "config" ? "configured" : "auto-selected (cheapest)";
    const costLabel = formatCost(selection.cost);

    ctx.ui.notify(`Commit: ${selection.model} [${sourceLabel}] — ${costLabel}`, "info");
  }

  pi.sendUserMessage(
    `Call the subagent tool with these exact parameters: ${JSON.stringify(payload)}`
  );
}

export default function generateCommitMessageExtension(pi: ExtensionAPI) {
  const baseCommand = {
    description: "Generate and stage semantic commits using a subagent",
    handler: async (args: string, ctx: ExtensionContext) => {
      runGenerateCommit(args, ctx, pi);
    },
  };

  const commitModelCommand = {
    description:
      "Configure model for commit generation. Usage: /commit-model [provider/model-name]",
    handler: async (args: string, ctx: ExtensionContext) => {
      const trimmedArgs = args.trim();
      let selectedModel: string | null = null;

      // If model provided as argument, validate and use it
      if (trimmedArgs && !trimmedArgs.includes(" ")) {
        // Single token = model name
        selectedModel = trimmedArgs;
      } else if (trimmedArgs) {
        // Multiple tokens = show model picker
        selectedModel = await selectModelInteractive(ctx);
        if (!selectedModel) {
          ctx.ui.notify("Model selection cancelled", "warning");
          return;
        }
      } else {
        // No arguments = show model picker
        selectedModel = await selectModelInteractive(ctx);
        if (!selectedModel) {
          ctx.ui.notify("Model selection cancelled", "warning");
          return;
        }
      }

      // Write configuration using config service
      try {
        const configService = await createConfigService<GenerateCommitMessageConfig>(CONFIG_NAME, {
          defaults: DEFAULT_CONFIG,
        });
        await configService.set("mode", selectedModel, "home");
        await configService.save("home");

        if (ctx.hasUI) {
          const cost = await getModelCost(ctx, selectedModel);
          const costLabel = formatCost(cost);
          ctx.ui.notify(`✓ Model configured: ${selectedModel} — ${costLabel}`, "info");
        }
      } catch (error) {
        ctx.ui.notify(
          `Failed to save configuration: ${error instanceof Error ? error.message : "unknown error"}`,
          "error"
        );
      }
    },
  };

  pi.registerCommand("commit", baseCommand);
  pi.registerCommand("commit-model", commitModelCommand);
}
