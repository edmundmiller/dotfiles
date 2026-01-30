// Deploy tool for NixOS/Darwin deployments via deploy-rs
import { tool } from "@opencode-ai/plugin";

export const deploy = tool({
  description:
    "Deploy NixOS/Darwin configuration to a host using deploy-rs. " +
    "Builds remotely on NUC, locally for Macs. " +
    "NUC has passwordless sudo for agentic deployments.",
  args: {
    host: tool.schema.string().describe("Host to deploy: 'nuc', 'MacTraitor-Pro', or 'Seqeratop'"),
    skipChecks: tool.schema.boolean().optional().describe("Skip flake checks (default: true)"),
    dryRun: tool.schema.boolean().optional().describe("Dry-run only, don't activate"),
  },
  async execute(args) {
    const cmd = ["nix", "run", "github:serokell/deploy-rs", "--", `.#${args.host}`];
    if (args.skipChecks !== false) cmd.push("--skip-checks");
    if (args.dryRun) cmd.push("--dry-activate");

    try {
      const result = await Bun.$`${cmd}`.cwd(process.env.HOME + "/.config/dotfiles").text();
      return result.trim();
    } catch (error: any) {
      return `Deploy failed: ${error.message}\n${error.stderr || ""}`;
    }
  },
});

export const deploy_check = tool({
  description: "Dry-run deploy to verify config without activating.",
  args: {
    host: tool.schema.string().optional().describe("Host to check (default: all)"),
  },
  async execute(args) {
    const cmd = ["nix", "run", "github:serokell/deploy-rs", "--"];
    cmd.push(args.host ? `.#${args.host}` : ".");
    cmd.push("--dry-activate", "--skip-checks");

    try {
      const result = await Bun.$`${cmd}`.cwd(process.env.HOME + "/.config/dotfiles").text();
      return result.trim();
    } catch (error: any) {
      return `Deploy check failed: ${error.message}`;
    }
  },
});

export const deploy_status = tool({
  description: "Check deployed NixOS host status via SSH.",
  args: {
    host: tool.schema.string().describe("Host: 'nuc'"),
  },
  async execute(args) {
    if (args.host !== "nuc") return "Status check only for NUC";
    try {
      const result =
        await Bun.$`ssh nuc "nixos-version && systemctl is-system-running && uptime"`.text();
      return `## NUC Status\n\n${result.trim()}`;
    } catch (error: any) {
      return `Status check failed: ${error.message}`;
    }
  },
});
