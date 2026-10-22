import { flue } from "@flue/runtime/routing";
import { Hono } from "hono";
import { createError } from "evlog";
import { evlog, type EvlogVariables } from "evlog/hono";
import { installObservability } from "./observability";

const telemetry = installObservability();
const routes = flue();
const app = new Hono<EvlogVariables>();
app.use("*", evlog({ drain: telemetry.drain }));
app.all("*", async (c) => {
  const log = c.get("log");
  log.set({ transport: "flue", accounting: "model-turn-leaves" });
  try {
    return await routes.fetch(c.req.raw, c.env);
  } catch {
    // Never export raw exceptions, which can contain prompts or provider credentials.
    throw createError({
      message: "Flue transport failed",
      why: "The Flue router could not complete the request",
      fix: "Inspect correlated operation and tool outcomes in the Flue ledger",
    });
  }
});

export default app;
