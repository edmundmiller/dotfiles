---
purpose: Prefer deterministic single-tool conversion when turning source content into markdown.
rule_id: AGENT-13
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-13.md
---

# Content Conversion

When converting files or URLs into markdown:

- Prefer one deterministic converter available in the environment.
- Prefer structured output modes when parsing downstream.
- Avoid ad-hoc multi-tool extraction chains unless required.
