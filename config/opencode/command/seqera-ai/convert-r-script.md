---
description: Convert R script to Nextflow process
model: opencode/claude-sonnet-4-5
---

R script to convert: $1

Script contents:
@$1

Current pipeline config:
@nextflow.config

Convert this R script to a Nextflow process. The script should likely be broken up into several processes if complex. First, create a plan. 1. Analyze the R script above to identify input files, parameters, and output files. 2. Outline the Nextflow process structure and dependency requirements. 3. Execute the plan: Create the Nextflow process with correct `input`, `output`, and `script` blocks, and handle R library dependencies by suggesting a container or conda environment. IMPORTANT: After creating the Nextflow process, run 'nextflow run . -preview' to verify the pipeline compiles correctly. If there are syntax errors, fix them. Then run 'nextflow lint' to check for best practice issues. Assume that nextflow is installed.

Additional context: $ARGUMENTS
