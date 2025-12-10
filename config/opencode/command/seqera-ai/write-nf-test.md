---
description: Generate nf-tests for untested code
model: opencode/claude-haiku-4-5
---

Nextflow processes in project:
!`find . -name "*.nf" -type f 2>/dev/null | grep -v ".nextflow" | head -30 || echo "No .nf files found"`

Existing nf-test files:
!`find . -name "*.nf.test" -type f 2>/dev/null | head -30 || echo "No .nf.test files found"`

nf-test availability:
!`command -v nf-test &>/dev/null && echo "nf-test is available" || echo "nf-test not found - install from https://code.askimed.com/nf-test/"`

Analyze the codebase above and write nf-tests for any untested portions. Identify modules and subworkflows (from the .nf files listed) that lack test coverage (no corresponding .nf.test file) and create comprehensive nf-test files following best practices.

Additional context: $ARGUMENTS
