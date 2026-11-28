import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

// The pinned public catalog predates the PR. Build only its static Google
// models locally, keeping every other provider on the immutable catalog.
const { buildCatalog } = await import(pathToFileURL(resolve("packages/ai/catalog/build.ts")));
const { default: googleAiPlan } = await import(
  pathToFileURL(resolve("packages/ai/catalog/providers/google-ai-plan.ts"))
);
const catalog = JSON.parse(readFileSync(process.argv[2], "utf8"));
catalog["google-ai-plan"] = buildCatalog(
  [googleAiPlan],
  {
    modelsDev: {},
    modelsDevDecisions: {},
    nvidiaModelIds: new Map(),
    openRouter: { chat: [], images: [], classifiers: [] },
    aiGateway: { chat: [], classifiers: [] },
    radius: { chat: [], images: [], classifiers: [] },
  },
  true
)["google-ai-plan"].chat;
writeFileSync("model-catalog.json", `${JSON.stringify(catalog)}\n`);
