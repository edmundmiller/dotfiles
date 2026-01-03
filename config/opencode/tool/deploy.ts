// Deploy tool for NixOS/Darwin deployments via deploy-rs
import { tool } from "@opencode-ai/plugin"

export const deploy = tool({
  description:
    "Deploy NixOS/Darwin configuration to a host using deploy-rs. " +
    "Builds remotely on target (for NUC) or locally (for Macs). " +
    "NUC has passwordless sudo configured for deploy-rs activation.",
  args: {
    host: tool.schema
      .string()
      .describe("Host to deploy to: 'nuc', 'MacTraitor-Pro', or 'Seqeratop'"),
    skipChecks: tool.schema
      .boolean()
      .optional()
      .describe("Skip flake checks (default: true for speed)"),
    dryRun: tool.schema
      .boolean()
      .optional()
      .describe("Dry-run only, don't actually activate"),
  },
  async execute(args) {
    const host = args.host
    const skipChecks = args.skipChecks !== false // default true
    const dryRun = args.dryRun || false

    const cmd = ["nix", "run", "github:serokell/deploy-rs", "--", `.#${host}`]

    if (skipChecks) cmd.push("--skip-checks")
    if (dryRun) cmd.push("--dry-activate")

    try {
      const result = await Bun.$`${cmd}`.cwd(process.env.HOME + "/.config/dotfiles").text()
      return result.trim()
    } catch (error: any) {
      return `Deploy failed: ${error.message}\n\nOutput: ${error.stdout || ""}\n${error.stderr || ""}`
    }
  },
})

export const deploy_check = tool({
  description:
    "Dry-run deploy to verify configuration without activating. " +
    "Useful to test that a deployment would succeed.",
  args: {
    host: tool.schema
      .string()
      .optional()
      .describe("Host to check (default: all hosts)"),
  },
  async execute(args) {
    const cmd = ["nix", "run", "github:serokell/deploy-rs", "--"]

    if (args.host) {
      cmd.push(`.#${args.host}`)
    } else {
      cmd.push(".")
    }

    cmd.push("--dry-activate", "--skip-checks")

    try {
      const result = await Bun.$`${cmd}`.cwd(process.env.HOME + "/.config/dotfiles").text()
      return result.trim()
    } catch (error: any) {
      return `Deploy check failed: ${error.message}\n\nOutput: ${error.stdout || ""}\n${error.stderr || ""}`
    }
  },
})

export const deploy_status = tool({
  description: "Check the status of a deployed NixOS host via SSH.",
  args: {
    host: tool.schema.string().describe("Host to check status: 'nuc'"),
  },
  async execute(args) {
    if (args.host !== "nuc") {
      return "Status check only supported for NUC currently"
    }

    try {
      const result = await Bun.$`ssh nuc "nixos-version && systemctl is-system-running && uptime"`.text()
      return `## NUC Status\n\n${result.trim()}`
    } catch (error: any) {
      return `Status check failed: ${error.message}`
    }
  },
})
