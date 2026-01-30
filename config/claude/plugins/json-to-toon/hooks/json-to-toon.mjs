#!/usr/bin/env bun

import { encode } from "./toon.mjs";

// Read input from stdin
let inputData = "";
process.stdin.setEncoding("utf8");

process.stdin.on("data", (chunk) => {
  inputData += chunk;
});

process.stdin.on("end", () => {
  try {
    const input = JSON.parse(inputData);
    const prompt = input.prompt || "";

    // Process the prompt to find and replace JSON blocks
    const processedPrompt = replaceJsonWithToon(prompt);

    // Output the modified prompt
    console.log(processedPrompt);
    process.exit(0);
  } catch (error) {
    // If there's an error, output the original prompt unchanged
    console.error(`Error in json-to-toon hook: ${error.message}`, { file: import.meta.url });
    try {
      const input = JSON.parse(inputData);
      console.log(input.prompt || "");
    } catch {
      console.log("");
    }
    process.exit(0);
  }
});

/**
 * Replaces JSON blocks, CSV, and Markdown tables with TOON format
 */
function replaceJsonWithToon(text) {
  // Pattern 1: Code blocks with csv/CSV language identifier
  text = text.replace(/```(?:csv|CSV)\s*\n([\s\S]*?)\n```/g, (match, csvContent) => {
    return convertCsvToToon(csvContent.trim(), true);
  });

  // Pattern 2: Markdown tables (must come before CSV to avoid conflicts)
  // Match markdown tables as complete blocks (header + separator + rows)
  text = text.replace(/(\|[^\n]+\|(?:\r?\n\|[^\n]+\|)+)/gm, (match) => {
    if (looksLikeMarkdownTable(match)) {
      return convertMarkdownTableToToon(match);
    }
    return match;
  });

  // Pattern 3: Code blocks with json/JSON language identifier
  text = text.replace(/```(?:json|JSON)\s*\n([\s\S]*?)\n```/g, (match, jsonContent) => {
    return convertJsonToToon(jsonContent.trim(), true);
  });

  // Pattern 4: Code blocks without language identifier that contain valid JSON or CSV
  text = text.replace(/```\s*\n([\s\S]*?)\n```/g, (match, content) => {
    const trimmed = content.trim();
    if (looksLikeCsv(trimmed)) {
      return convertCsvToToon(trimmed, true);
    }
    if (looksLikeJson(trimmed)) {
      return convertJsonToToon(trimmed, true);
    }
    return match; // Keep original if not JSON or CSV
  });

  // Pattern 5: Inline JSON objects/arrays (be conservative to avoid false positives)
  // Use a more robust approach: try to find complete JSON structures
  text = text.replace(
    /(\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}|\[[^\[\]]*(?:\[[^\[\]]*\][^\[\]]*)*\])/g,
    (match) => {
      // Only convert if it's valid JSON, looks like data (not code), and is substantial
      if (match.length >= 30 && looksLikeJson(match) && !looksLikeCode(match)) {
        return convertJsonToToon(match, false);
      }
      return match;
    }
  );

  return text;
}

/**
 * Attempts to parse and convert JSON to TOON format
 */
function convertJsonToToon(jsonString, isCodeBlock) {
  try {
    const parsed = JSON.parse(jsonString);
    const toonEncoded = encode(parsed);

    // If it was in a code block, return it in a code block
    if (isCodeBlock) {
      return "```\n" + toonEncoded + "\n```";
    }

    return toonEncoded;
  } catch (error) {
    // If parsing fails, return original
    return isCodeBlock ? "```json\n" + jsonString + "\n```" : jsonString;
  }
}

/**
 * Checks if a string looks like JSON
 */
function looksLikeJson(str) {
  const trimmed = str.trim();
  if (!trimmed) return false;

  // Must start with { or [
  if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) {
    return false;
  }

  try {
    JSON.parse(trimmed);
    return true;
  } catch {
    return false;
  }
}

/**
 * Checks if JSON looks like code rather than data
 * (heuristic to avoid converting JavaScript/TypeScript code)
 */
function looksLikeCode(str) {
  // If it contains function keyword, arrow functions, or common JS patterns
  const codePatterns = [
    /function\s*\(/,
    /=>\s*{/,
    /\bconst\b/,
    /\blet\b/,
    /\bvar\b/,
    /\bif\s*\(/,
    /\bfor\s*\(/,
    /\bwhile\s*\(/,
  ];

  return codePatterns.some((pattern) => pattern.test(str));
}

/**
 * Infers the type of a string value (number, boolean, or string)
 */
function inferType(value) {
  if (value === "" || value == null) return value;

  // Try to parse as number
  const num = Number(value);
  if (!isNaN(num) && value.trim() !== "") {
    return num;
  }

  // Check for boolean
  const lower = value.toLowerCase();
  if (lower === "true") return true;
  if (lower === "false") return false;

  // Otherwise return as string
  return value;
}

/**
 * Manually generates TOON table format from headers and rows
 * Format: [N]{col1,col2,col3}:\n  val1,val2,val3\n  ...
 */
function generateToonTable(headers, rows) {
  // Format cell value for TOON (add quotes if needed)
  const formatCell = (value) => {
    if (value == null || value === "") return "";
    if (typeof value === "number" || typeof value === "boolean") return String(value);

    const str = String(value);
    // Quote if contains comma, colon, or looks like a number/boolean
    if (
      str.includes(",") ||
      str.includes(":") ||
      str.includes("-") ||
      /^(true|false|\d+)$/i.test(str.trim())
    ) {
      return `"${str.replace(/"/g, '\\"')}"`;
    }
    return str;
  };

  // Build TOON format
  const rowCount = rows.length;
  const headerLine = `[${rowCount}]{${headers.join(",")}}:`;

  const dataLines = rows.map((row) => {
    const formattedCells = row.map(formatCell);
    return "  " + formattedCells.join(",");
  });

  return [headerLine, ...dataLines].join("\n");
}

/**
 * Checks if a string looks like CSV
 */
function looksLikeCsv(str) {
  const lines = str.trim().split("\n");
  if (lines.length < 2) return false;

  // Check if first line has delimiters (comma, tab, or pipe)
  const firstLine = lines[0];
  const hasDelimiters = /[,\t|]/.test(firstLine);
  if (!hasDelimiters) return false;

  // Detect delimiter (most common in first line)
  const delimiter = detectDelimiter(firstLine);
  const firstLineFields = parseCsvLine(firstLine, delimiter).length;

  // Check if multiple lines have similar field counts
  let consistentLines = 0;
  for (let i = 1; i < Math.min(lines.length, 5); i++) {
    const fieldCount = parseCsvLine(lines[i], delimiter).length;
    if (fieldCount === firstLineFields) {
      consistentLines++;
    }
  }

  return consistentLines >= Math.min(lines.length - 1, 2);
}

/**
 * Detects the delimiter used in a CSV line
 */
function detectDelimiter(line) {
  const delimiters = [",", "\t", "|"];
  let maxCount = 0;
  let bestDelimiter = ",";

  for (const delim of delimiters) {
    const count = (line.match(new RegExp(`\\${delim}`, "g")) || []).length;
    if (count > maxCount) {
      maxCount = count;
      bestDelimiter = delim;
    }
  }

  return bestDelimiter;
}

/**
 * Parses a single CSV line, handling quoted fields
 */
function parseCsvLine(line, delimiter = ",") {
  const fields = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    const nextChar = line[i + 1];

    if (char === '"') {
      if (inQuotes && nextChar === '"') {
        // Escaped quote
        current += '"';
        i++; // Skip next quote
      } else {
        // Toggle quote state
        inQuotes = !inQuotes;
      }
    } else if (char === delimiter && !inQuotes) {
      // End of field
      fields.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }

  // Add last field
  fields.push(current.trim());

  return fields;
}

/**
 * Converts CSV to TOON format manually (bypassing encode to avoid nesting issues)
 */
function convertCsvToToon(csvString, isCodeBlock) {
  try {
    const lines = csvString
      .trim()
      .split("\n")
      .filter((line) => line.trim());
    if (lines.length < 2) return isCodeBlock ? "```csv\n" + csvString + "\n```" : csvString;

    const delimiter = detectDelimiter(lines[0]);
    const headers = parseCsvLine(lines[0], delimiter);
    const rows = [];

    for (let i = 1; i < lines.length; i++) {
      const fields = parseCsvLine(lines[i], delimiter);
      if (fields.length === headers.length) {
        rows.push(fields.map((f) => inferType(f)));
      }
    }

    if (rows.length === 0) {
      return isCodeBlock ? "```csv\n" + csvString + "\n```" : csvString;
    }

    // Manually generate TOON format
    const toonEncoded = generateToonTable(headers, rows);

    if (isCodeBlock) {
      return "```\n" + toonEncoded + "\n```";
    }

    return toonEncoded;
  } catch (error) {
    return isCodeBlock ? "```csv\n" + csvString + "\n```" : csvString;
  }
}

/**
 * Checks if text looks like a Markdown table
 */
function looksLikeMarkdownTable(str) {
  const lines = str.trim().split(/\r?\n/);
  if (lines.length < 3) return false;

  // All lines should start and end with |
  const hasPipes = lines.every((line) => {
    const trimmed = line.trim();
    return trimmed.startsWith("|") && trimmed.endsWith("|");
  });
  if (!hasPipes) return false;

  // Check for separator line (contains pattern like |---|---| or |:---|---:| etc)
  const separatorPattern = /^\|[\s:-]+\|/;
  return lines.some((line) => {
    const trimmed = line.trim();
    // Separator line should have only spaces, dashes, colons, and pipes
    return separatorPattern.test(trimmed) && /^[\|:\s-]+$/.test(trimmed);
  });
}

/**
 * Parses a markdown table row
 */
function parseMarkdownTableRow(line) {
  return line
    .split("|")
    .slice(1, -1) // Remove first and last empty elements from split
    .map((cell) => cell.trim());
}

/**
 * Converts Markdown table to TOON format
 */
function convertMarkdownTableToToon(tableString) {
  try {
    const lines = tableString
      .trim()
      .split("\n")
      .filter((line) => line.trim());
    if (lines.length < 3) return tableString;

    // Parse header row
    const headers = parseMarkdownTableRow(lines[0]);

    // Skip separator row (index 1)
    // Parse data rows (from index 2 onwards)
    const rows = [];
    for (let i = 2; i < lines.length; i++) {
      const cells = parseMarkdownTableRow(lines[i]);
      if (cells.length === headers.length) {
        rows.push(cells.map((c) => inferType(c)));
      }
    }

    if (rows.length === 0) return tableString;

    // Manually generate TOON format
    return generateToonTable(headers, rows);
  } catch (error) {
    return tableString;
  }
}
