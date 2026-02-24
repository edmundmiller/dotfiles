/**
 * Secret pattern detection for outgoing requests.
 * Ported from scurl's SecretDefender.
 */

export interface SecretPattern {
  name: string;
  pattern: RegExp;
  description: string;
}

export const SECRET_PATTERNS: SecretPattern[] = [
  // AWS
  {
    name: "AWS Access Key ID",
    pattern: /AKIA[0-9A-Z]{16}/,
    description: "AWS Access Key ID",
  },
  {
    name: "AWS Secret Key",
    pattern: /(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])/,
    description: "Potential AWS Secret Access Key (40 char base64)",
  },
  // GitHub
  {
    name: "GitHub PAT (classic)",
    pattern: /ghp_[A-Za-z0-9]{36}/,
    description: "GitHub Personal Access Token (classic)",
  },
  {
    name: "GitHub PAT (fine-grained)",
    pattern: /github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}/,
    description: "GitHub Personal Access Token (fine-grained)",
  },
  {
    name: "GitHub OAuth",
    pattern: /gho_[A-Za-z0-9]{36}/,
    description: "GitHub OAuth Access Token",
  },
  {
    name: "GitHub App Token",
    pattern: /ghs_[A-Za-z0-9]{36}/,
    description: "GitHub App Installation Token",
  },
  {
    name: "GitHub Refresh Token",
    pattern: /ghr_[A-Za-z0-9]{36}/,
    description: "GitHub Refresh Token",
  },
  // GitLab
  {
    name: "GitLab PAT",
    pattern: /glpat-[A-Za-z0-9\-]{20}/,
    description: "GitLab Personal Access Token",
  },
  // npm
  {
    name: "npm Token",
    pattern: /npm_[A-Za-z0-9]{36}/,
    description: "npm Access Token",
  },
  // PyPI
  {
    name: "PyPI Token",
    pattern: /pypi-[A-Za-z0-9\-_]{50,}/,
    description: "PyPI API Token",
  },
  // Slack
  {
    name: "Slack Bot Token",
    pattern: /xoxb-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24}/,
    description: "Slack Bot Token",
  },
  {
    name: "Slack User Token",
    pattern: /xoxp-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24}/,
    description: "Slack User Token",
  },
  // Stripe
  {
    name: "Stripe Live Key",
    pattern: /sk_live_[A-Za-z0-9]{24,}/,
    description: "Stripe Live Secret Key",
  },
  {
    name: "Stripe Test Key",
    pattern: /sk_test_[A-Za-z0-9]{24,}/,
    description: "Stripe Test Secret Key",
  },
  // Google
  {
    name: "Google API Key",
    pattern: /AIza[0-9A-Za-z\-_]{35}/,
    description: "Google API Key",
  },
  // Twilio
  {
    name: "Twilio API Key",
    pattern: /SK[0-9a-fA-F]{32}/,
    description: "Twilio API Key",
  },
  // SendGrid
  {
    name: "SendGrid API Key",
    pattern: /SG\.[A-Za-z0-9\-_]{22}\.[A-Za-z0-9\-_]{43}/,
    description: "SendGrid API Key",
  },
  // DigitalOcean
  {
    name: "DigitalOcean PAT",
    pattern: /dop_v1_[a-f0-9]{64}/,
    description: "DigitalOcean Personal Access Token",
  },
  // Doppler
  {
    name: "Doppler Token",
    pattern: /dp\.pt\.[A-Za-z0-9]{43}/,
    description: "Doppler Personal Token",
  },
  // Discord
  {
    name: "Discord Bot Token",
    pattern: /[MN][A-Za-z\d]{23,}\.[\w-]{6}\.[\w-]{27}/,
    description: "Discord Bot Token",
  },
  // Generic
  {
    name: "Private Key",
    pattern: /-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/,
    description: "Private Key (PEM format)",
  },
  {
    name: "Password in URL",
    pattern: /:\/\/[^:]+:[^@]+@/,
    description: "Password embedded in URL",
  },
  // Anthropic
  {
    name: "Anthropic API Key",
    pattern: /sk-ant-[A-Za-z0-9\-_]{80,}/,
    description: "Anthropic API Key",
  },
  // OpenAI
  {
    name: "OpenAI API Key",
    pattern: /sk-[A-Za-z0-9]{48,}/,
    description: "OpenAI API Key",
  },
];

export interface SecretScanResult {
  found: boolean;
  pattern?: SecretPattern;
  location?: string;
}

/**
 * Scan text for leaked secrets. Returns first match.
 */
export function scanForSecrets(text: string): SecretPattern | null {
  for (const p of SECRET_PATTERNS) {
    if (p.pattern.test(text)) return p;
  }
  return null;
}

/**
 * Scan a URL (including query params) for secrets.
 */
export function scanUrl(url: string): SecretScanResult {
  // Full URL
  const match = scanForSecrets(url);
  if (match) return { found: true, pattern: match, location: "URL" };

  // Query params individually
  try {
    const parsed = new URL(url);
    for (const [, value] of parsed.searchParams) {
      const m = scanForSecrets(value);
      if (m) return { found: true, pattern: m, location: "query parameter" };
    }
  } catch {
    // Invalid URL, skip param parsing
  }

  return { found: false };
}

/**
 * Scan request headers for secrets. Skips Authorization header.
 */
export function scanHeaders(headers: Record<string, string>): SecretScanResult {
  for (const [name, value] of Object.entries(headers)) {
    if (name.toLowerCase() === "authorization") continue;
    const m = scanForSecrets(value);
    if (m) return { found: true, pattern: m, location: `header '${name}'` };
  }
  return { found: false };
}
