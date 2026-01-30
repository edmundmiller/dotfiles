// nf-workflow-overview.ts - Nextflow pipeline overview tool
// Custom tool for OpenCode that provides high-level pipeline structure analysis
import { tool } from "@opencode-ai/plugin";

const AST_GREP_DIR = `${process.env.HOME}/.config/opencode/ast-grep`;

/**
 * Get a comprehensive overview of a Nextflow pipeline
 */
export const overview = tool({
  description:
    "Get a comprehensive overview of a Nextflow pipeline including structure, processes, workflows, and configuration. Perfect for understanding unfamiliar pipelines without reading all files.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Pipeline directory (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    const sections: string[] = [];

    // Check if this looks like a Nextflow pipeline
    try {
      await Bun.$`test -f ${dir}/main.nf || test -f ${dir}/nextflow.config || ls ${dir}/*.nf 2>/dev/null`.quiet();
    } catch {
      return `Directory does not appear to be a Nextflow pipeline (no main.nf, nextflow.config, or .nf files found)`;
    }

    // Get pipeline name from directory
    const pipelineName = dir.split("/").pop() || "pipeline";
    sections.push(`## Pipeline Overview: ${pipelineName}\n`);

    // Structure summary
    try {
      const structureLines: string[] = [];
      structureLines.push("### Structure");

      // Count local modules
      try {
        const localModules =
          await Bun.$`find ${dir}/modules/local -name '*.nf' 2>/dev/null | wc -l`.text();
        const count = parseInt(localModules.trim()) || 0;
        if (count > 0) structureLines.push(`modules/local/       ${count} files`);
      } catch {
        /* no local modules */
      }

      // Count nf-core modules (main.nf files)
      try {
        const nfcoreModules =
          await Bun.$`find ${dir}/modules/nf-core -name 'main.nf' 2>/dev/null | wc -l`.text();
        const count = parseInt(nfcoreModules.trim()) || 0;
        if (count > 0) structureLines.push(`modules/nf-core/     ${count} modules`);
      } catch {
        /* no nf-core modules */
      }

      // Count local subworkflows
      try {
        const localSub =
          await Bun.$`find ${dir}/subworkflows/local -name '*.nf' 2>/dev/null | wc -l`.text();
        const count = parseInt(localSub.trim()) || 0;
        if (count > 0) structureLines.push(`subworkflows/local/  ${count} files`);
      } catch {
        /* no local subworkflows */
      }

      // Count nf-core subworkflows
      try {
        const nfcoreSub =
          await Bun.$`find ${dir}/subworkflows/nf-core -name 'main.nf' 2>/dev/null | wc -l`.text();
        const count = parseInt(nfcoreSub.trim()) || 0;
        if (count > 0) structureLines.push(`subworkflows/nf-core/ ${count} subworkflows`);
      } catch {
        /* no nf-core subworkflows */
      }

      // Count workflows
      try {
        const workflows =
          await Bun.$`find ${dir}/workflows -name '*.nf' 2>/dev/null | wc -l`.text();
        const count = parseInt(workflows.trim()) || 0;
        if (count > 0) structureLines.push(`workflows/           ${count} workflow(s)`);
      } catch {
        /* no workflows directory */
      }

      if (structureLines.length > 1) {
        sections.push(structureLines.join("\n"));
      }
    } catch {
      /* structure analysis failed */
    }

    // Find workflows using ast-grep
    try {
      const namedWorkflows =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p 'workflow _NAME { ___ }' -l nextflow ${dir} 2>/dev/null`.text();
      if (namedWorkflows.trim()) {
        const workflowNames = namedWorkflows
          .trim()
          .split("\n")
          .map((line) => {
            // Extract workflow name from match
            const match = line.match(/workflow\s+(\w+)/);
            return match ? match[1] : line.split(":")[0];
          })
          .filter((v, i, a) => a.indexOf(v) === i) // unique
          .slice(0, 10); // limit

        sections.push(`### Workflows\n${workflowNames.map((w) => `- ${w}`).join("\n")}`);
      }
    } catch {
      /* ast-grep not available or no matches */
    }

    // Count processes using ast-grep
    try {
      const processes =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p 'process _NAME { ___ }' -l nextflow ${dir} 2>/dev/null`.text();
      if (processes.trim()) {
        const processCount = processes.trim().split("\n").length;
        sections.push(`### Processes\nTotal: ${processCount} process definitions`);
      }
    } catch {
      /* ast-grep not available or no matches */
    }

    // Key parameters from config
    try {
      const configFile = `${dir}/nextflow.config`;
      const paramsBlock =
        await Bun.$`awk '/^params\\s*\\{/,/^\\}/' ${configFile} 2>/dev/null | head -30`.text();
      if (paramsBlock.trim()) {
        // Extract key params (required ones and common ones)
        const paramLines = paramsBlock
          .split("\n")
          .filter((line) => line.includes("=") && !line.trim().startsWith("//"))
          .map((line) => line.trim())
          .slice(0, 10);

        if (paramLines.length > 0) {
          sections.push(
            `### Key Parameters (from nextflow.config)\n\`\`\`groovy\n${paramLines.join("\n")}\n\`\`\``
          );
        }
      }
    } catch {
      /* config parsing failed */
    }

    // Check for schema
    try {
      await Bun.$`test -f ${dir}/nextflow_schema.json`.quiet();
      sections.push(
        `### Schema\nnextflow_schema.json present - use nf-core schema commands for full parameter docs`
      );
    } catch {
      /* no schema */
    }

    return sections.join("\n\n") || "Unable to analyze pipeline structure";
  },
});

/**
 * Show directory tree of pipeline components
 */
export const tree = tool({
  description:
    "Show the directory tree of Nextflow pipeline components (modules, subworkflows, workflows). Excludes non-essential files like work/, results/, .git/.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Pipeline directory (defaults to current directory)"),
    depth: tool.schema.string().optional().describe("Max depth for tree (default: 3)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    const depth = args.depth || "3";

    try {
      // Check if tree command is available
      await Bun.$`command -v tree`.quiet();

      const result =
        await Bun.$`tree ${dir} -L ${depth} -I 'node_modules|.git|work|results|.nextflow*|__pycache__|*.pyc' --dirsfirst -F 2>/dev/null`.text();
      return result.trim() || "No directory structure found";
    } catch {
      // Fallback to find if tree is not available
      try {
        const result =
          await Bun.$`find ${dir} -maxdepth ${depth} \\( -name 'node_modules' -o -name '.git' -o -name 'work' -o -name 'results' -o -name '.nextflow*' \\) -prune -o -type f -name '*.nf' -print 2>/dev/null | sort`.text();
        return result.trim() || "No .nf files found";
      } catch (error) {
        return `Error getting tree: ${error instanceof Error ? error.message : "Unknown error"}`;
      }
    }
  },
});

/**
 * Extract include statements showing dependencies
 */
export const includes = tool({
  description:
    "Extract and display all include statements from Nextflow files, showing the dependency graph between modules, subworkflows, and workflows.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Pipeline directory (defaults to current directory)"),
    file: tool.schema
      .string()
      .optional()
      .describe("Specific .nf file to analyze (defaults to analyzing main entry files)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();

    try {
      let result: string;

      if (args.file) {
        // Analyze specific file
        result =
          await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p "include { ___ } from '___'" -l nextflow ${args.file} 2>/dev/null`.text();
      } else {
        // Analyze main entry files
        const files = ["main.nf", "workflows/*.nf", "subworkflows/**/main.nf"];
        const results: string[] = [];

        for (const pattern of files) {
          try {
            const matches =
              await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p "include { ___ } from '___'" -l nextflow ${dir}/${pattern} 2>/dev/null`.text();
            if (matches.trim()) {
              results.push(`## ${pattern}\n${matches.trim()}`);
            }
          } catch {
            // Pattern didn't match any files
          }
        }

        result = results.join("\n\n");
      }

      if (!result.trim()) {
        // Fallback to grep
        const grepResult =
          await Bun.$`grep -rh "^include\\s*{" ${dir}/*.nf ${dir}/workflows/*.nf ${dir}/subworkflows/**/*.nf 2>/dev/null | head -50`.text();
        return grepResult.trim() || "No include statements found";
      }

      return result.trim();
    } catch (error) {
      return `Error extracting includes: ${error instanceof Error ? error.message : "Unknown error"}`;
    }
  },
});

/**
 * Extract params from nextflow.config
 */
export const config_params = tool({
  description:
    "Extract params block from nextflow.config showing available parameters with their default values. Also checks for nextflow_schema.json.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Pipeline directory (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    const sections: string[] = [];

    // Extract params block from nextflow.config
    try {
      const configFile = `${dir}/nextflow.config`;
      const paramsBlock =
        await Bun.$`awk '/^params\\s*\\{/,/^\\}/' ${configFile} 2>/dev/null`.text();

      if (paramsBlock.trim()) {
        sections.push(
          `## Parameters from nextflow.config\n\`\`\`groovy\n${paramsBlock.trim()}\n\`\`\``
        );
      }
    } catch {
      sections.push("No params block found in nextflow.config");
    }

    // Check for schema and extract key info
    try {
      const schemaFile = `${dir}/nextflow_schema.json`;
      await Bun.$`test -f ${schemaFile}`.quiet();

      // Get definitions/properties count
      const schemaInfo =
        await Bun.$`jq -r '.definitions | keys | length' ${schemaFile} 2>/dev/null`.text();
      const groupCount = parseInt(schemaInfo.trim()) || 0;

      // Get required params
      const required =
        await Bun.$`jq -r '.definitions | to_entries[] | select(.value.required != null) | .value.required[]' ${schemaFile} 2>/dev/null | sort -u | head -10`.text();

      let schemaSection = `## Schema Info\n- ${groupCount} parameter groups defined`;
      if (required.trim()) {
        schemaSection += `\n- Required: ${required.trim().split("\n").join(", ")}`;
      }
      schemaSection += `\n\nRun \`nf-core schema docs\` for full parameter documentation`;

      sections.push(schemaSection);
    } catch {
      // No schema file
    }

    return sections.join("\n\n") || "No configuration found";
  },
});

/**
 * Quick count of pipeline components
 */
export const component_count = tool({
  description:
    "Quick count of pipeline components: processes, workflows, subworkflows, modules (local vs nf-core). Fast way to gauge pipeline complexity.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe("Pipeline directory (defaults to current directory)"),
  },
  async execute(args) {
    const dir = args.directory || process.cwd();
    const counts: string[] = [];
    counts.push(`## Component Count: ${dir.split("/").pop()}\n`);

    // Count processes using ast-grep
    try {
      const processes =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p 'process _NAME { ___ }' -l nextflow ${dir} 2>/dev/null`.text();
      const processCount = processes.trim() ? processes.trim().split("\n").length : 0;
      counts.push(`Processes:        ${processCount}`);
    } catch {
      counts.push(`Processes:        (ast-grep unavailable)`);
    }

    // Count workflows using ast-grep
    try {
      const workflows =
        await Bun.$`cd ${AST_GREP_DIR} && ast-grep -p 'workflow _NAME { ___ }' -l nextflow ${dir} 2>/dev/null`.text();
      const workflowCount = workflows.trim() ? workflows.trim().split("\n").length : 0;
      counts.push(`Workflows:        ${workflowCount}`);
    } catch {
      counts.push(`Workflows:        (ast-grep unavailable)`);
    }

    // Count by directory
    const directories = [
      { path: "modules/local", label: "Local modules" },
      { path: "modules/nf-core", label: "nf-core modules" },
      { path: "subworkflows/local", label: "Local subworkflows" },
      { path: "subworkflows/nf-core", label: "nf-core subworkflows" },
    ];

    for (const { path, label } of directories) {
      try {
        const count = await Bun.$`find ${dir}/${path} -name '*.nf' 2>/dev/null | wc -l`.text();
        const num = parseInt(count.trim()) || 0;
        if (num > 0) {
          counts.push(`${label.padEnd(18)} ${num}`);
        }
      } catch {
        // Directory doesn't exist
      }
    }

    // Count config files
    try {
      const configs = await Bun.$`find ${dir}/conf -name '*.config' 2>/dev/null | wc -l`.text();
      const configCount = parseInt(configs.trim()) || 0;
      if (configCount > 0) {
        counts.push(`Config files:     ${configCount}`);
      }
    } catch {
      // No conf directory
    }

    return counts.join("\n");
  },
});
