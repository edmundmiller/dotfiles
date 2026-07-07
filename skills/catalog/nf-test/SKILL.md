---
name: nf-test
description: Use when writing or changing nf-test tests, Nextflow process/workflow tests, nf-core module tests, snapshots, `nf-test test`, or `.nf.test` files.
---

# nf-test

nf-test work should be **pipeline-real**: run the smallest Nextflow process or workflow that proves the data contract, then snapshot only stable artifacts.

## Loop

1. **Locate the target.** Read the process/workflow `main.nf`, its existing `tests/main.nf.test`, local `nextflow.config`, and root `nf-test.config`. Stop when inputs, outputs, tags, profiles, and snapshots are understood.

2. **Write one focused test.** Add one `test("...")` block for the missing behavior: single-end vs paired-end, optional output, config branch, error mode, or workflow wiring.

3. **Build realistic inputs.** Use tiny nf-core/modules test data, `Channel.of`, real `file(..., checkIfExists: true)`, and a representative meta map. Avoid fake paths that would pass only because the process never used them.

4. **Assert semantic facts first.** Check `process.success`, emitted optional outputs, key report/log text, and channel shape. Use snapshots for file tuples, checksums, and `versions` after the semantic assertions.

5. **Run narrow.** Prefer `nf-test test path/to/main.nf.test --profile test` or the repo's documented command. Completion criterion: the new test fails before the change for the expected reason and passes after snapshots are reviewed.

## House style

- Keep `nf-test.config` as the shared home for `testsDir`, `workDir`, `configFile`, `profile`, plugins, and triggers.
- Use `NFT_WORKDIR` when a clean or isolated work directory matters; otherwise let `.nf-test` hold test work.
- Tag tests with useful selectors such as `modules`, `modules_nfcore`, and the tool/process name.
- Keep module tests close to the module: `modules/<scope>/<name>/tests/main.nf.test`.
- Use per-test `config './nextflow.some-mode.config'` for mode-specific process settings instead of mutating global config.
- Prefer `assertAll` so one run reports every broken part of the contract.
- Snapshot only deterministic outputs: files, tuple structures, and `versions`. Do not snapshot logs when one explicit `contains(...)` assertion captures the behavior.
- Inspect snapshot diffs before updating. Do not refresh snapshots just to make a failing behavior green.

## Process test skeleton

```groovy
nextflow_process {

    name "Test Process FASTP"
    script "../main.nf"
    process "FASTP"
    tag "modules"
    tag "modules_nfcore"
    tag "fastp"

    test("test_fastp_single_end") {
        when {
            process {
                """
                input[0] = Channel.of([
                    [ id:'test', single_end:true ],
                    [ file(params.modules_testdata_base_path + 'genomics/sarscov2/illumina/fastq/test_1.fastq.gz', checkIfExists: true) ]
                ])
                input[1] = []
                input[2] = false
                input[3] = false
                input[4] = false
                """
            }
        }

        then {
            assertAll(
                { assert process.success },
                { assert path(process.out.html.get(0).get(1)).getText().contains("single end") },
                { assert snapshot(process.out.json, process.out.reads, process.out.versions).match() }
            )
        }
    }
}
```

## Root config skeleton

```groovy
config {
    testsDir "."
    workDir System.getenv("NFT_WORKDIR") ?: ".nf-test"
    configFile "tests/nextflow.config"
    profile "test"
    plugins {
        load "nft-bam@0.5.0"
        load "nft-utils@0.0.3"
    }
    triggers "nextflow.config", "nf-test.config", "tests/nextflow.config"
}
```

## Commands

- Current file from editor convention: `nf-test test %`.
- Specific file: `nf-test test modules/nf-core/fastp/tests/main.nf.test`.
- Isolated work dir: `NFT_WORKDIR=$(mktemp -d) nf-test test path/to/main.nf.test`.
- Snapshot update only after review: use the repo's documented nf-test snapshot update command.
