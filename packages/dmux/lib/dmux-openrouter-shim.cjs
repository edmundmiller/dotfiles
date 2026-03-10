// dmux-openrouter-shim: intercept OpenRouter chat completions and delegate to dmux-ai-infer.

const { spawnSync } = require("node:child_process");

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const originalFetch = globalThis.fetch ? globalThis.fetch.bind(globalThis) : null;

if (originalFetch) {
  globalThis.fetch = async function dmuxShimmedFetch(input, init = {}) {
    const url = typeof input === "string" || input instanceof URL ? String(input) : input?.url;
    if (!url || !url.startsWith(OPENROUTER_URL)) {
      return originalFetch(input, init);
    }

    const provider = process.env.DMUX_AI_PROVIDER || "auto";
    if (provider === "openrouter") {
      return originalFetch(input, init);
    }

    const inferBin = process.env.DMUX_AI_INFER_BIN || "dmux-ai-infer";
    let payload = {};
    if (typeof init.body === "string" && init.body.trim()) {
      try {
        payload = JSON.parse(init.body);
      } catch {
        payload = {};
      }
    }

    const result = spawnSync(inferBin, ["infer"], {
      input: JSON.stringify(payload),
      encoding: "utf8",
      stdio: ["pipe", "pipe", "pipe"],
      timeout: Number(process.env.DMUX_AI_TIMEOUT_MS || "20000") + 1000,
      maxBuffer: 8 * 1024 * 1024,
      env: process.env,
    });

    if (!result.error && result.status === 0) {
      try {
        const parsed = JSON.parse((result.stdout || "").trim());
        const content = typeof parsed?.content === "string" ? parsed.content : "";
        return new Response(
          JSON.stringify({
            id: "dmux-local-shim",
            object: "chat.completion",
            choices: [
              {
                index: 0,
                message: { role: "assistant", content },
                finish_reason: "stop",
              },
            ],
          }),
          {
            status: 200,
            headers: { "content-type": "application/json" },
          }
        );
      } catch {
        // fall through
      }
    }

    const realKey = process.env.DMUX_OPENROUTER_REAL_KEY;
    if (realKey) {
      const restoredHeaders = {
        ...(init.headers || {}),
        Authorization: `Bearer ${realKey}`,
      };
      return originalFetch(input, { ...init, headers: restoredHeaders });
    }

    const message = (
      result.stderr ||
      result.error?.message ||
      "dmux inference bridge failed"
    ).trim();
    return new Response(JSON.stringify({ error: { message } }), {
      status: 503,
      headers: { "content-type": "application/json" },
    });
  };
}
