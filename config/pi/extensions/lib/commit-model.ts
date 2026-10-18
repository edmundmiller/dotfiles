import type { ExtensionContext } from "@mariozechner/pi-coding-agent";

export interface ModelInfo {
  id: string;
  provider: string;
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
}

interface AutoModelSelection {
  model: string;
  source: "auto";
  cost: ModelInfo["cost"] | null;
}

export function normalizeMode(mode?: string): string | undefined {
  if (!mode) return undefined;
  const trimmed = mode.trim();
  if (!trimmed) return undefined;
  return /^[^/\s]+\/[^\s]+$/.test(trimmed) ? trimmed : undefined;
}

function calculateCostScore(model: ModelInfo): number {
  const { input, output } = model.cost;
  if (input === 0 && output === 0) return Number.MAX_SAFE_INTEGER;
  return input + output * 2;
}

function isCheapModelName(id: string): boolean {
  return /(mini|flash|nano|haiku|lite|micro|free)/i.test(id);
}

function isModelInfo(value: unknown): value is ModelInfo {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;

  const id = Reflect.get(value, "id");
  const provider = Reflect.get(value, "provider");
  const cost = Reflect.get(value, "cost");
  if (typeof id !== "string" || typeof provider !== "string") return false;
  if (typeof cost !== "object" || cost === null || Array.isArray(cost)) return false;

  return (
    typeof Reflect.get(cost, "input") === "number" &&
    typeof Reflect.get(cost, "output") === "number" &&
    typeof Reflect.get(cost, "cacheRead") === "number" &&
    typeof Reflect.get(cost, "cacheWrite") === "number"
  );
}

export async function getAvailableModels(ctx: ExtensionContext): Promise<ModelInfo[]> {
  const available = await ctx.modelRegistry.getAvailable();
  if (!Array.isArray(available)) return [];
  return available.filter(isModelInfo);
}

export async function pickCheapestModel(
  ctx: ExtensionContext,
  maxOutputCost: number = 1.0
): Promise<AutoModelSelection> {
  const available = await getAvailableModels(ctx);
  if (available.length === 0) {
    return { model: "github-copilot/gpt-4o-mini", source: "auto", cost: null };
  }

  const tokenBased = available.filter(
    (model) => !(model.cost.input === 0 && model.cost.output === 0)
  );

  const cheapModels = tokenBased
    .filter((model) => model.cost.output <= maxOutputCost)
    .sort((left, right) => calculateCostScore(left) - calculateCostScore(right));
  const cheapestUnderCap = cheapModels[0];
  if (cheapestUnderCap) {
    return {
      model: `${cheapestUnderCap.provider}/${cheapestUnderCap.id}`,
      source: "auto",
      cost: cheapestUnderCap.cost,
    };
  }

  const cheapNamed = tokenBased
    .filter((model) => isCheapModelName(model.id))
    .sort((left, right) => calculateCostScore(left) - calculateCostScore(right));
  const cheapestNamed = cheapNamed[0];
  if (cheapestNamed) {
    return {
      model: `${cheapestNamed.provider}/${cheapestNamed.id}`,
      source: "auto",
      cost: cheapestNamed.cost,
    };
  }

  const cheapestTokenBased = [...tokenBased].sort(
    (left, right) => calculateCostScore(left) - calculateCostScore(right)
  )[0];
  if (cheapestTokenBased) {
    return {
      model: `${cheapestTokenBased.provider}/${cheapestTokenBased.id}`,
      source: "auto",
      cost: cheapestTokenBased.cost,
    };
  }

  const cheapestAvailable = [...available].sort(
    (left, right) => calculateCostScore(left) - calculateCostScore(right)
  )[0];
  return {
    model: `${cheapestAvailable.provider}/${cheapestAvailable.id}`,
    source: "auto",
    cost: cheapestAvailable.cost,
  };
}

export async function getModelCost(
  ctx: ExtensionContext,
  modelString: string
): Promise<ModelInfo["cost"] | null> {
  const [provider, ...idParts] = modelString.split("/");
  const modelId = idParts.join("/");
  const available = await getAvailableModels(ctx);
  const found = available.find((model) => model.provider === provider && model.id === modelId);
  return found ? found.cost : null;
}
