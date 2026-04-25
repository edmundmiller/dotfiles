---
purpose: Hard rules for file hygiene, commit splitting, and output format.
rule_id: AGENT-02
enforced_by: prompt
severity: error
waiver_path: .agents/waivers/AGENT-02.md
---

# Critical Instructions

- **ALWAYS overwrite the source file.** No "\_enhanced", "\_fixed", "\_updated", or "\_v2" copies. We use version control. If unsure, commit first then overwrite.
- Don't make "dashboards" or multi-plot figures in one image. Hard for AIs to parse.
