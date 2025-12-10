---
description: Migrate WDL pipeline to Nextflow
model: opencode/claude-sonnet-4-5
---

WDL files in project:
!`find . -name "*.wdl" -type f 2>/dev/null | head -20 || echo "No WDL files found in current directory"`

Working directory status:
!`git status --short 2>/dev/null || ls -la`

Existing Nextflow config (if any):
@nextflow.config

Start a migration workflow to convert this WDL pipeline to Nextflow. First, create a comprehensive migration plan. 1. Analyze all WDL files (listed above) and identify the workflow structure, inputs, tasks, and outputs. 2. List the corresponding Nextflow components (processes, channels, workflows) needed. 3. Review the plan to ensure no logic is missed. 4. Begin a piece-meal execution plan, converting the pipeline step-by-step, starting with the base configuration and input handling, then moving to individual tasks, and finally the workflow logic. IMPORTANT: After each major conversion step (e.g., after converting a process or workflow section), run 'nextflow run . -preview' to verify the pipeline compiles correctly. If there are syntax errors, fix them before proceeding to the next step. Once the full conversion is complete, run both 'nextflow lint' and 'nextflow run . -preview' to ensure everything is working as expected. Assume that nextflow is installed.

Additional context: $ARGUMENTS
