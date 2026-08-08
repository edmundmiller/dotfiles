---
purpose: Prefer deterministic single-tool conversion when turning source content into markdown.
rule_id: AGENT-13
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-13.md
---

# Content Conversion

When converting files or URLs into markdown:

- Prefer the runtime's native page-reading or browsing tool when it returns clean main content.
- For shell-based URL extraction, use `bunx defuddle parse <url> --md`; add `--frontmatter` when source metadata matters.
- Use a lower-level HTML-to-Markdown converter only when full-document fidelity, streaming, or offline stdin conversion is required.
- Prefer one deterministic converter available in the environment.
- Prefer structured output modes when parsing downstream.
- Avoid ad-hoc multi-tool extraction chains unless required.
