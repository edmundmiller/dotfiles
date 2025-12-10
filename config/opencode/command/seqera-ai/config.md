---
description: Generate nextflow.config file for pipeline
---

Current pipeline structure:
@main.nf

Existing config (if any):
@nextflow.config

Project files:
!`ls -la`

Generate a comprehensive 'nextflow.config' file for this pipeline. Analyze the pipeline logic above to identify necessary process resource requirements (cpus, memory, time) and container requirements. Include profiles for different execution environments (e.g., 'standard' for local, 'docker', 'singularity', 'awsbatch'). Follow nf-core best practices for configuration structure.

If a config already exists above, enhance it rather than replacing it completely.

Additional context: $ARGUMENTS
