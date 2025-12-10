---
description: Run pipeline diagnostics
model: opencode/claude-haiku-4-5
---

Pipeline configuration:
@nextflow.config

Main workflow:
@main.nf

Lint check output:
!`nextflow lint 2>&1 || echo "Linting not available or errors encountered"`

Config validation:
!`nextflow config 2>&1 | head -50 || echo "Config validation failed"`

Preview check:
!`nextflow run . -preview 2>&1 | head -100 || echo "Preview check failed - see errors above"`

Debug this Nextflow pipeline by analyzing the diagnostic outputs above. Identify syntax errors, best practice violations, configuration issues, and compilation problems. Provide specific fixes for each issue found.

Additional context: $ARGUMENTS
