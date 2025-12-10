---
description: Debug last Seqera Platform run
model: opencode/claude-haiku-4-5
---

Recent Seqera Platform runs (tw CLI):
!`tw runs list --limit 5 2>/dev/null || echo "Seqera CLI (tw) not found or not configured. Set TOWER_ACCESS_TOKEN environment variable."`

Pipeline configuration:
@nextflow.config

Local workflow definition:
@main.nf

Debug the last run on Seqera Platform. If the tw CLI output above shows recent runs, analyze their status and identify failures. If tw CLI is not available, guide the user to:

1. Install tw CLI: https://github.com/seqeralabs/tower-cli
2. Set TOWER_ACCESS_TOKEN environment variable
3. Use the Seqera Platform web interface to view logs

Provide recommendations for fixing issues based on available information.

Additional context: $ARGUMENTS
