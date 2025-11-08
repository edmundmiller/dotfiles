#!/usr/bin/env bun

import { encode } from './toon.mjs';

// Read input from stdin
let inputData = '';
process.stdin.setEncoding('utf8');

process.stdin.on('data', (chunk) => {
  inputData += chunk;
});

process.stdin.on('end', () => {
  try {
    const input = JSON.parse(inputData);
    const prompt = input.prompt || '';

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
      console.log(input.prompt || '');
    } catch {
      console.log('');
    }
    process.exit(0);
  }
});

/**
 * Replaces JSON blocks and inline JSON with TOON format
 */
function replaceJsonWithToon(text) {
  // Pattern 1: Code blocks with json/JSON language identifier
  text = text.replace(/```(?:json|JSON)\s*\n([\s\S]*?)\n```/g, (match, jsonContent) => {
    return convertJsonToToon(jsonContent.trim(), true);
  });

  // Pattern 2: Code blocks without language identifier that contain valid JSON
  text = text.replace(/```\s*\n([\s\S]*?)\n```/g, (match, content) => {
    const trimmed = content.trim();
    if (looksLikeJson(trimmed)) {
      return convertJsonToToon(trimmed, true);
    }
    return match; // Keep original if not JSON
  });

  // Pattern 3: Inline JSON objects/arrays (be conservative to avoid false positives)
  // Use a more robust approach: try to find complete JSON structures
  text = text.replace(/(\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}|\[[^\[\]]*(?:\[[^\[\]]*\][^\[\]]*)*\])/g, (match) => {
    // Only convert if it's valid JSON, looks like data (not code), and is substantial
    if (match.length >= 30 && looksLikeJson(match) && !looksLikeCode(match)) {
      return convertJsonToToon(match, false);
    }
    return match;
  });

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
      return '```\n' + toonEncoded + '\n```';
    }

    return toonEncoded;
  } catch (error) {
    // If parsing fails, return original
    return isCodeBlock ? '```json\n' + jsonString + '\n```' : jsonString;
  }
}

/**
 * Checks if a string looks like JSON
 */
function looksLikeJson(str) {
  const trimmed = str.trim();
  if (!trimmed) return false;

  // Must start with { or [
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
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

  return codePatterns.some(pattern => pattern.test(str));
}
