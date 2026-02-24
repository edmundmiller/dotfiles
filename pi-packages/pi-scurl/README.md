# pi-scurl

Secure web fetch extension for [pi](https://github.com/badlogic/pi-mono). Fetches URLs and returns clean, LLM-optimized markdown.

Inspired by [scurl](https://github.com/sibyllinesoft/scurl), rebuilt in TypeScript with [mdream](https://github.com/harlan-zw/mdream) for HTML-to-markdown conversion.

## Features

- **HTML → Markdown** via mdream (~50-99% token reduction)
- **Secret scanning** — blocks outgoing requests containing API keys, tokens, private keys
- **Prompt injection detection** — regex-based detection with configurable actions (warn/redact/tag)
- **Output truncation** — stays within pi's context limits

## Tool: `web_fetch`

```
web_fetch(url, options?)
```

| Parameter          | Type    | Default  | Description                                       |
| ------------------ | ------- | -------- | ------------------------------------------------- |
| `url`              | string  | required | URL to fetch                                      |
| `raw`              | boolean | false    | Skip HTML-to-markdown conversion                  |
| `minimal`          | boolean | true     | Use mdream minimal preset (strips nav, ads, etc.) |
| `headers`          | object  | {}       | Custom request headers                            |
| `timeout`          | number  | 30000    | Request timeout in ms                             |
| `injection_action` | enum    | "warn"   | Action on injection: warn, redact, tag, none      |

## Secret Patterns

Detects 25+ secret formats: AWS, GitHub, GitLab, Slack, Stripe, Google, npm, PyPI, OpenAI, Anthropic, and more. Authorization headers are excluded (expected to contain tokens).

## Injection Detection

Pattern categories: instruction override, role injection, system manipulation, prompt leak, jailbreak keywords, encoding markers, suspicious delimiters.

Actions:

- **warn** — wraps in `<suspected-prompt-injection>` + `<untrusted>` tags
- **redact** — masks matched patterns with █ characters
- **tag** — wraps in `<untrusted>` tags only
- **none** — disabled

## Install

Referenced as a local package in `config/pi/settings.jsonc`:

```jsonc
"~/.config/dotfiles/packages/pi-scurl"
```

Deps installed automatically by nix activation.
