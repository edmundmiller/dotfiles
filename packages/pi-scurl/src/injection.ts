/**
 * Prompt injection detection via regex pattern matching.
 * Ported from scurl's PromptInjectionDefender (pattern-only mode).
 *
 * No ML/embedding dependencies — pure regex + text statistics.
 */

/** Regex patterns by category for detecting prompt injection. */
const PATTERN_CATEGORIES: Record<string, RegExp[]> = {
  instruction_override: [
    /ignore\s+(all\s+)?(previous|prior|above|earlier|preceding)\s+(instructions?|prompts?|rules?|guidelines?|directions?|commands?)/i,
    /disregard\s+(all\s+)?(previous|prior|earlier|above|preceding)/i,
    /forget\s+(everything\s+)?(above|before|prior|previous|earlier)/i,
    /do\s+not\s+follow\s+(the\s+)?(previous|above|prior|earlier)/i,
    /override\s+(all\s+)?(previous|prior|earlier)/i,
    /stop\s+following\s+(your\s+)?(previous|original|initial)/i,
    /new\s+instructions?\s*[:=]/i,
    /actual\s+instructions?\s*[:=]/i,
    /real\s+instructions?\s*[:=]/i,
    /updated?\s+instructions?\s*[:=]/i,
  ],
  role_injection: [
    /you\s+are\s+now\s+/i,
    /from\s+now\s+on\s*[,:]?\s*(you|your)/i,
    /act\s+as\s+(if\s+)?(you\s+)?(are\s+|were\s+)?/i,
    /pretend\s+(to\s+be|you\s+are|you're|that\s+you)/i,
    /your\s+new\s+(role|goal|purpose|instruction|directive|objective)/i,
    /imagine\s+(that\s+)?you\s+(are|were)/i,
    /roleplay\s+as/i,
    /switch\s+to\s+.{0,30}\s+mode/i,
    /you\s+must\s+now\s+(act|be|become)/i,
    /for\s+the\s+rest\s+of\s+this\s+(conversation|session|chat)/i,
    /behave\s+(like|as)\s+(a|an)/i,
    /assume\s+the\s+(role|identity|persona)/i,
    /you\s+will\s+(now\s+)?(respond|act|behave)/i,
  ],
  system_manipulation: [
    /(admin|administrator|developer|god|sudo|root|maintenance|debug)\s+mode/i,
    /system\s+(override|prompt|instruction|message|command)/i,
    /unlock\s+(all\s+)?(restrictions?|capabilities?|features?|access)/i,
    /disable\s+(all\s+)?(safety|security|content\s+)?(filters?|guards?|restrictions?|limits?)/i,
    /bypass\s+(all\s+)?(restrictions?|filters?|safety|security|limits?)/i,
    /enable\s+(unrestricted|unlimited|full)\s+(mode|access)/i,
    /remove\s+(all\s+)?(limitations?|restrictions?|filters?)/i,
    /without\s+(any\s+)?(restrictions?|limitations?|filters?)/i,
    /turn\s+off\s+(safety|security|content)?\s*(filters?|checks?|restrictions?)/i,
    /deactivate\s+(safety|security|content)\s+(filters?|checks?)/i,
    /override\s+safety/i,
    /ignore\s+(safety|content)\s+(guidelines?|policies?|filters?)/i,
  ],
  prompt_leak: [
    /reveal\s+(your\s+)?(system\s+)?(prompt|instructions?|directives?)/i,
    /show\s+(me\s+)?(your\s+)?(system\s+)?(prompt|instructions?|rules?|directives?)/i,
    /what\s+(are|is|were)\s+(your\s+)?(system\s+)?(prompt|instructions?|rules?|directives?)/i,
    /(print|display|output|echo|write|repeat)\s+(your\s+)?(system\s+)?(prompt|instructions?|directives?)/i,
    /tell\s+me\s+(your|the)\s+(system\s+)?(prompt|instructions?)/i,
    /(initial|original|hidden|secret|base)\s+(prompt|instructions?|directives?)/i,
    /what\s+were\s+you\s+(told|instructed|programmed)/i,
    /(copy|paste|quote)\s+(your\s+)?(system\s+)?(prompt|instructions?)/i,
    /(beginning|start)\s+of\s+(your\s+)?(prompt|instructions?)/i,
  ],
  jailbreak_keywords: [
    /\bDAN\b/,
    /\bjailbreak(ed|ing)?\b/i,
    /do\s+anything\s+now/i,
    /(evil|dark|shadow|unrestricted|unfiltered)\s+(mode|assistant|ai|version)/i,
    /(no|without|ignore)\s+(ethical|moral)\s+(guidelines?|restrictions?|limits?)/i,
    /hypothetically\s+(speaking|if)/i,
    /for\s+(educational|research|academic)\s+purposes?\s+only/i,
    /in\s+a\s+fictional\s+(scenario|world|context)/i,
    /(opposite|anti)\s+day/i,
    /chaos\s+mode/i,
    /maximum\s+freedom/i,
    /no\s+censorship/i,
    /uncensored\s+(mode|response|version)/i,
    /(bypass|skip|avoid)\s+(all\s+)?safeguards?/i,
  ],
  encoding_markers: [
    /base64\s*[:=]/i,
    /decode\s+(this|the\s+following|below)/i,
    /encoded\s+(message|instruction|prompt)/i,
    /\\x[0-9a-fA-F]{2}/,
    /&#x?[0-9a-fA-F]+;/,
    /%[0-9a-fA-F]{2}/,
    /\\u[0-9a-fA-F]{4}/,
    /rot13/i,
    /caesar\s+cipher/i,
  ],
  suspicious_delimiters: [
    /\[\s*system\s*\]/i,
    /\[\s*instructions?\s*\]/i,
    /\[\s*admin\s*\]/i,
    /\[\s*assistant\s*\]/i,
    /\[\s*user\s*\]/i,
    /<\|?\s*(system|instruction|user|assistant|im_start|im_end)\s*\|?>/i,
    /###\s*(system|instruction|new\s+task)/i,
    /\*\*\*\s*(override|system|admin)/i,
    /={3,}\s*(system|instruction|override)/i,
    /```\s*(system|instruction|override)/i,
    /---\s*(system|instruction|begin)/i,
  ],
};

const REDACT_CHAR = "█";

export type InjectionAction = "warn" | "redact" | "tag" | "none";

export interface InjectionSpan {
  start: number;
  end: number;
}

export interface InjectionAnalysis {
  /** Composite score 0.0–1.0 */
  score: number;
  /** Whether score >= threshold */
  flagged: boolean;
  /** Per-category scores (matches per 1000 chars, capped 1.0) */
  categories: Record<string, number>;
  /** Active signal type short codes */
  signals: string[];
  /** Matched character spans for redaction */
  spans: InjectionSpan[];
}

/** Count regex matches normalized per 1k chars, capped at 1.0 */
function density(patterns: RegExp[], text: string, len: number): number {
  let count = 0;
  for (const p of patterns) {
    const g = new RegExp(p.source, p.flags.includes("g") ? p.flags : p.flags + "g");
    const m = text.match(g);
    if (m) count += m.length;
  }
  return Math.min((count * 1000) / len, 1.0);
}

/**
 * Analyze text for prompt injection signals.
 * Pure pattern-based — no ML dependencies.
 */
export function analyzeInjection(text: string, threshold = 0.3): InjectionAnalysis {
  const len = Math.max(text.length, 1);

  // Per-category densities
  const categories: Record<string, number> = {};
  for (const [cat, patterns] of Object.entries(PATTERN_CATEGORIES)) {
    categories[cat] = density(patterns, text, len);
  }

  // Any signal present?
  const active = Object.entries(categories).filter(([, v]) => v > 0);
  const hasSignal = active.length > 0;

  // Composite score: weighted average of active categories + text stats boost
  let score = 0;
  if (hasSignal) {
    // Weights: instruction_override and role_injection weigh more
    const weights: Record<string, number> = {
      instruction_override: 3.0,
      role_injection: 2.5,
      system_manipulation: 2.0,
      prompt_leak: 2.0,
      jailbreak_keywords: 2.5,
      encoding_markers: 1.0,
      suspicious_delimiters: 1.5,
    };
    let wSum = 0;
    let wTotal = 0;
    for (const [cat, val] of Object.entries(categories)) {
      const w = weights[cat] ?? 1;
      wSum += val * w;
      wTotal += w;
    }
    score = Math.min((wSum / wTotal) * 10, 1.0); // scale up (densities are small)
  }

  const flagged = score >= threshold;

  // Short codes for active categories
  const codeMap: Record<string, string> = {
    instruction_override: "override",
    role_injection: "role",
    system_manipulation: "system",
    prompt_leak: "leak",
    jailbreak_keywords: "jailbreak",
    encoding_markers: "encoding",
    suspicious_delimiters: "delimiters",
  };
  const signals = active.map(([k]) => codeMap[k] ?? k);

  // Find spans if flagged
  const spans: InjectionSpan[] = [];
  if (flagged) {
    const allSpans: InjectionSpan[] = [];
    for (const patterns of Object.values(PATTERN_CATEGORIES)) {
      for (const p of patterns) {
        const g = new RegExp(p.source, p.flags.includes("g") ? p.flags : p.flags + "g");
        let m: RegExpExecArray | null;
        while ((m = g.exec(text)) !== null) {
          allSpans.push({ start: m.index, end: m.index + m[0].length });
        }
      }
    }
    // Merge overlapping
    allSpans.sort((a, b) => a.start - b.start);
    for (const s of allSpans) {
      const last = spans[spans.length - 1];
      if (last && s.start <= last.end) {
        last.end = Math.max(last.end, s.end);
      } else {
        spans.push({ ...s });
      }
    }
  }

  return { score, flagged, categories, signals, spans };
}

/**
 * Redact matched spans with block characters.
 */
export function redactSpans(text: string, spans: InjectionSpan[]): string {
  if (!spans.length) return text;
  const parts: string[] = [];
  let last = 0;
  for (const { start, end } of spans) {
    parts.push(text.slice(last, start));
    parts.push(REDACT_CHAR.repeat(end - start));
    last = end;
  }
  parts.push(text.slice(last));
  return parts.join("");
}

/**
 * Wrap content with injection warning tags + untrusted wrapper.
 */
export function wrapInjection(
  content: string,
  analysis: InjectionAnalysis,
  action: InjectionAction
): string {
  let processed = content;

  if (analysis.flagged && action === "redact") {
    processed = redactSpans(content, analysis.spans);
  }

  if (analysis.flagged && action !== "none") {
    const score = analysis.score.toFixed(2);
    const signals = analysis.signals.join(",") || "semantic";
    processed = `<suspected-prompt-injection p="${score}" t="${signals}">\n${processed}\n</suspected-prompt-injection>`;
  }

  return `<untrusted>\n${processed}\n</untrusted>`;
}
