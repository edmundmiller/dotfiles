import path from "node:path";

const SOURCE_POLICY_PATH = "config/pi/pi-permission-system.jsonc";
const OMP_POLICY_PATH = ".omp/agent/extensions/pi-permission-system/config.json";

const GUIDANCE_LINES = [
  [
    "Why: config/pi/pi-permission-system.jsonc is the shared Pi/OMP permission policy,",
    "so an OMP agent must not inspect or rewrite its own guardrails opportunistically.",
  ].join(" "),
  "Use instead:",
  [
    "- For OMP-only safety behavior, edit",
    "config/omp/extensions/permission-policy-guard/hooks/pre/protect-permission-policy.js.",
  ].join(" "),
  [
    "- For OMP module wiring, edit modules/agents/omp/default.nix",
    "and config/omp/config.yml.",
  ].join(" "),
  [
    "- For shared Pi permission-policy changes, stop and ask for an explicit",
    "dotfiles policy change.",
  ].join(" "),
];

export function buildBlockReason(match) {
  return [`OMP policy guard blocked a tool call touching ${match}.`, ...GUIDANCE_LINES].join("\n");
}

function normalized(value) {
  return value.replaceAll("\\", "/");
}

function protectedPathCandidates(cwd) {
  const home = process.env.HOME || "";
  return [
    SOURCE_POLICY_PATH,
    path.resolve(cwd, SOURCE_POLICY_PATH),
    OMP_POLICY_PATH,
    home ? path.join(home, OMP_POLICY_PATH) : "",
    "~/.omp/agent/extensions/pi-permission-system/config.json",
  ]
    .filter(Boolean)
    .map(normalized);
}

function collectStrings(value, seen = new Set()) {
  if (typeof value === "string") return [value];
  if (!value || typeof value !== "object") return [];
  if (seen.has(value)) return [];
  seen.add(value);

  const values = Array.isArray(value) ? value : Object.values(value);
  return values.flatMap((entry) => collectStrings(entry, seen));
}

export function findProtectedPolicyReference(input, cwd = process.cwd()) {
  const candidates = protectedPathCandidates(cwd);

  for (const raw of collectStrings(input)) {
    const text = normalized(raw);
    const match = candidates.find((candidate) => text.includes(candidate));
    if (match) return match;
  }

  return null;
}

export default function permissionPolicyGuard(pi) {
  pi.on("tool_call", async (event, ctx) => {
    const match = findProtectedPolicyReference(event.input, ctx.cwd);
    if (!match) return undefined;

    if (ctx.hasUI) {
      ctx.ui.notify(`Blocked protected permission policy access: ${match}`, "warning");
    }

    return {
      block: true,
      reason: buildBlockReason(match),
    };
  });
}
