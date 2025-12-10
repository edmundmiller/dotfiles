---
description: Generate Nextflow schema
---

Pipeline configuration:
@nextflow.config

Main workflow:
@main.nf

Existing schema (if any):
@nextflow_schema.json

nf-core availability check:
!`command -v nf-core &>/dev/null && echo "nf-core is available" || echo "nf-core not found"`

Help the user generate a Nextflow schema. First, recommend running 'nf-core schema build' as it is the standard tool for this. If 'nf-core' is not available, ask the user if they want to install it (via 'pip install nf-core') or if they prefer you to generate the 'nextflow_schema.json' manually. If manual generation is requested: Generate a comprehensive 'nextflow_schema.json' for this pipeline following the nf-core best practices and JSON Schema Draft 7 specification. Analyze the 'nextflow.config' and 'main.nf' files above to identify all pipeline parameters. Structure the schema with appropriate types, default values, descriptions, and help text. Group related parameters (e.g., 'Input/Output', 'Resource Options') using the 'definitions' keyword to create a user-friendly interface in Nextflow Tower/Seqera Platform.

Additional context: $ARGUMENTS
