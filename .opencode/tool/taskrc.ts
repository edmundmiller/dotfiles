// taskrc.ts - View and edit Taskwarrior reports and configuration
import { tool } from "@opencode-ai/plugin";

const TASKRC_PATH = `${Bun.env.HOME}/.config/dotfiles/config/taskwarrior/taskrc`;
const USER_TASKRC = `${Bun.env.HOME}/.taskrc`;

// Ensure ~/.taskrc includes repo directly (not stale nix store path)
async function ensureDirectInclude() {
  const content = await Bun.file(USER_TASKRC).text();
  if (content.includes("/nix/store/") && content.includes("taskwarrior/taskrc")) {
    const updated = content.replace(
      /include \/nix\/store\/[^/]+\/config\/taskwarrior\/taskrc/,
      `include ${TASKRC_PATH}`
    );
    await Bun.write(USER_TASKRC, updated);
    return true;
  }
  return false;
}

export default tool({
  description:
    "View and edit Taskwarrior reports and configuration. Can list reports, show report details, or update report settings. Automatically ensures ~/.taskrc points to repo for immediate effect.",
  args: {
    action: tool.schema
      .enum(["list", "show", "update"])
      .describe("Action: list reports, show report config, or update a report"),
    report: tool.schema
      .string()
      .optional()
      .describe("Report name (e.g., 'today', 'next', 'crisis')"),
    field: tool.schema
      .enum(["filter", "columns", "labels", "sort", "description"])
      .optional()
      .describe("Report field to update"),
    value: tool.schema.string().optional().describe("New value for the field"),
  },
  async execute(args) {
    try {
      switch (args.action) {
        case "list": {
          // List all custom reports defined in taskrc
          const content = await Bun.file(TASKRC_PATH).text();
          const reports = new Set<string>();
          const lines = content.split("\n");

          for (const line of lines) {
            const match = line.match(/^report\.([^.]+)\./);
            if (match) reports.add(match[1]);
          }

          // Get descriptions for each report
          const reportInfo: string[] = [];
          for (const report of Array.from(reports).sort()) {
            const descLine = lines.find((l) => l.startsWith(`report.${report}.description=`));
            const desc = descLine?.split("=")[1] || "(no description)";
            reportInfo.push(`  ${report}: ${desc}`);
          }

          return `Custom reports in taskrc:\n\n${reportInfo.join("\n")}`;
        }

        case "show": {
          if (!args.report) {
            return "Error: 'report' parameter required for show action";
          }

          // Show current config for a specific report
          const result = await Bun.$`task show report.${args.report}`.text();
          return result;
        }

        case "update": {
          if (!args.report || !args.field || !args.value) {
            return "Error: 'report', 'field', and 'value' parameters required for update action";
          }

          // Ensure direct include for immediate effect
          const fixedInclude = await ensureDirectInclude();

          const content = await Bun.file(TASKRC_PATH).text();
          const lines = content.split("\n");
          const key = `report.${args.report}.${args.field}`;
          const newLine = `${key}=${args.value}`;

          let found = false;
          const updatedLines = lines.map((line) => {
            if (line.startsWith(`${key}=`)) {
              found = true;
              return newLine;
            }
            return line;
          });

          if (!found) {
            // Find where to insert - after other report.X lines or at end of report section
            const lastReportIdx = lines.findLastIndex((l) =>
              l.startsWith(`report.${args.report}.`)
            );
            if (lastReportIdx >= 0) {
              updatedLines.splice(lastReportIdx + 1, 0, newLine);
            } else {
              return `Error: Report '${args.report}' not found in taskrc. Create it first with all required fields.`;
            }
          }

          await Bun.write(TASKRC_PATH, updatedLines.join("\n"));

          // Verify the change
          const verify = await Bun.$`task show report.${args.report}.${args.field}`.text();
          const includeNote = fixedInclude
            ? "\n\n(Updated ~/.taskrc to include repo directly)"
            : "";
          return `Updated ${key}:\n\n${verify}${includeNote}`;
        }

        default:
          return "Unknown action";
      }
    } catch (error: any) {
      return `Error: ${error.message}`;
    }
  },
});
