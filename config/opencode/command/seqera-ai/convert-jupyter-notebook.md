---
description: Convert Jupyter Notebook to Nextflow process
model: opencode/claude-sonnet-4-5
---

Jupyter notebook to convert: $1

Notebook contents:
@$1

Current pipeline config:
@nextflow.config

Convert this Jupyter Notebook to a Nextflow process. The notebook should likely be broken up into several processes if complex. First, create a plan. 1. Analyze the notebook above to understand the analysis steps, inputs, and outputs. 2. Outline the Nextflow process structure and container requirements. 3. Execute the plan: Extract the relevant code cells, create the Nextflow process wrapping this logic, define the input/output channels, and define the container environment. IMPORTANT: After creating the Nextflow process, run 'nextflow run . -preview' to verify the pipeline compiles correctly. If there are syntax errors, fix them. Then run 'nextflow lint' to check for best practice issues. Assume that nextflow is installed.

Additional context: $ARGUMENTS
