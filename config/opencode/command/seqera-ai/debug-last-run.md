---
description: Debug last local Nextflow run
model: opencode/claude-haiku-4-5
---

Recent Nextflow execution:
!`nextflow log -last 2>/dev/null || echo "No Nextflow execution history found"`

Latest log entries (.nextflow.log):
!`tail -100 .nextflow.log 2>/dev/null || echo "No .nextflow.log file found"`

Pipeline configuration:
@nextflow.config

Work directory status:
!`ls -la work/ 2>/dev/null | head -20 || echo "No work directory found"`

Debug the last local Nextflow run based on the context above. Analyze the execution logs, identify what went wrong, and provide actionable fixes.

Additional context: $ARGUMENTS
