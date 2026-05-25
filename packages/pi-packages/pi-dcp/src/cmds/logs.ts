/**
 * /dcp-logs command - View pi-dcp logs
 *
 * Shows recent log entries and provides information about log file locations.
 */

import type { CommandDefinition } from "../types";
import { getLogger } from "../logger";
import { readFileSync, existsSync, statSync } from "fs";

export const dcpLogsCommand: CommandDefinition = {
  description: "View pi-dcp extension logs",
  handler: async (args, ctx) => {
    const logger = getLogger();

    // Parse args string for --lines and --file flags
    const linesMatch = args.match(/--lines\s+(\d+)/);
    const fileMatch = args.match(/--file\s+(\d+)/);
    const linesToShow = linesMatch ? parseInt(linesMatch[1], 10) : 50;
    const fileIndex = fileMatch ? parseInt(fileMatch[1], 10) : 0;

    // Get all log files
    const allLogFiles = logger.getAllLogFiles();

    if (allLogFiles.length === 0) {
      ctx.ui.notify("📋 No log files found. Logs will be created when extension runs.", "info");
      return;
    }

    // Validate file index
    if (fileIndex < 0 || fileIndex >= allLogFiles.length) {
      ctx.ui.notify(
        `❌ Invalid file index. Available: 0 (current) to ${allLogFiles.length - 1} (oldest backup)`,
        "error"
      );
      return;
    }

    const logFilePath = allLogFiles[fileIndex];

    if (!existsSync(logFilePath)) {
      ctx.ui.notify(`❌ Log file not found: ${logFilePath}`, "error");
      return;
    }

    // Get file info
    const stats = statSync(logFilePath);
    const fileSizeMB = (stats.size / (1024 * 1024)).toFixed(2);

    // Read the file
    const content = readFileSync(logFilePath, "utf8");
    const lines = content.split("\n").filter((line) => line.trim());

    // Get last N lines
    const recentLines = lines.slice(-linesToShow);

    // Build response
    let response = `📋 pi-dcp Logs\n\n`;
    response += `File: ${logFilePath}\n`;
    response += `Size: ${fileSizeMB} MB\n`;
    response += `Total Lines: ${lines.length}\n`;
    response += `Showing: Last ${recentLines.length} lines\n\n`;
    response += recentLines.join("\n");

    // Show available files
    if (allLogFiles.length > 1) {
      response += "\n\nAvailable log files:\n";
      allLogFiles.forEach((file, idx) => {
        const size = existsSync(file) ? (statSync(file).size / (1024 * 1024)).toFixed(2) : "0";
        const label = idx === 0 ? "current" : `backup ${idx}`;
        response += `- ${idx}: ${label} (${size} MB)\n`;
      });
      response += "\nUse /dcp-logs --file <number> to view a specific file.";
    }

    ctx.ui.notify(response, "info");
  },
};
