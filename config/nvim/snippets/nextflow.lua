-- Nextflow snippets for LuaSnip
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

return {
  -- Basic process template
  s("process", fmt([[
process {} {{
    {}

    input:
    {}

    output:
    {}

    script:
    """
    {}
    """
}}
]], {
    i(1, "PROCESS_NAME"),
    c(2, {
      t(""),
      t("publishDir params.outdir, mode: 'copy'"),
      t("container 'biocontainers/tool:version'"),
      fmt("publishDir params.outdir, mode: 'copy'\n    container '{}'", { i(1, "container:tag") }),
    }),
    i(3, "val sample_id\n    path input_file"),
    i(4, "path 'output.txt', emit: output"),
    i(5, "echo 'Processing ${sample_id}'\n    command_here"),
  })),

  -- Workflow template
  s("workflow", fmt([[
workflow {} {{
    take:
    {}

    main:
    {}

    emit:
    {}
}}
]], {
    i(1, "WORKFLOW_NAME"),
    i(2, "input_channel"),
    i(3, "// workflow logic here"),
    i(4, "output_channel"),
  })),

  -- Channel creation
  s("channel", fmt([[
{} = Channel
    .{}({})
    {}
]], {
    i(1, "ch_input"),
    c(2, {
      t("fromPath"),
      t("fromFilePairs"),
      t("value"),
      t("from"),
    }),
    i(3, "'*.fastq'"),
    c(4, {
      t(""),
      fmt(".set {{ {} }}", { i(1, "channel_name") }),
      t(".collect()"),
      t(".flatten()"),
    }),
  })),

  -- Input declaration
  s("input", fmt([[
input:
{}
]], {
    c(1, {
      fmt("val {}", { i(1, "sample_id") }),
      fmt("path {}", { i(1, "input_file") }),
      fmt("tuple val({}), path({})", { i(1, "sample_id"), i(2, "reads") }),
      fmt("path {}, stageAs: '{}'", { i(1, "input_file"), i(2, "staged_name") }),
    }),
  })),

  -- Output declaration
  s("output", fmt([[
output:
{}
]], {
    c(1, {
      fmt("path '{}', emit: {}", { i(1, "output.txt"), i(2, "output") }),
      fmt("tuple val({}), path('{}'), emit: {}", { i(1, "sample_id"), i(2, "output.txt"), i(3, "output") }),
      fmt("path '{}', optional: true", { i(1, "optional_output.txt") }),
    }),
  })),

  -- Script block
  s("script", fmt([[
script:
"""
{}
"""
]], {
    i(1, "#!/bin/bash\necho 'Hello World'"),
  })),

  -- Shell block
  s("shell", fmt([[
shell:
'''
{}
'''
]], {
    i(1, "#!/bin/bash\necho 'Processing !{sample_id}'"),
  })),

  -- When condition
  s("when", fmt([[
when:
{}
]], {
    c(1, {
      fmt("params.{}", { i(1, "run_process") }),
      fmt("{} != null", { i(1, "sample_id") }),
      fmt("!params.{}", { i(1, "skip_process") }),
    }),
  })),

  -- Container directive
  s("container", fmt([[
container '{}'
]], {
    c(1, {
      i(1, "biocontainers/tool:version"),
      i(1, "quay.io/biocontainers/tool:version"),
      i(1, "docker://image:tag"),
    }),
  })),

  -- PublishDir directive
  s("publishDir", fmt([[
publishDir '{}', mode: '{}'{}
]], {
    i(1, "results/"),
    c(2, {
      t("copy"),
      t("symlink"),
      t("move"),
      t("link"),
    }),
    c(3, {
      t(""),
      fmt(", pattern: '{}'", { i(1, "*.txt") }),
      fmt(", saveAs: {{ filename -> {} }}", { i(1, "filename.replaceAll('.tmp', '')") }),
    }),
  })),

  -- Error strategy
  s("errorStrategy", fmt([[
errorStrategy '{}'
]], {
    c(1, {
      t("terminate"),
      t("ignore"),
      t("retry"),
      t("finish"),
    }),
  })),

  -- Memory directive
  s("memory", fmt([[
memory '{}'
]], {
    c(1, {
      i(1, "4.GB"),
      i(1, "8.GB"),
      i(1, "16.GB"),
      i(1, "32.GB"),
    }),
  })),

  -- CPU directive
  s("cpus", fmt([[
cpus {}
]], {
    c(1, {
      i(1, "1"),
      i(1, "2"),
      i(1, "4"),
      i(1, "8"),
    }),
  })),

  -- Time directive
  s("time", fmt([[
time '{}'
]], {
    c(1, {
      i(1, "1.h"),
      i(1, "2.h"),
      i(1, "4.h"),
      i(1, "1.d"),
    }),
  })),

  -- Complete process with common patterns
  s("proc", fmt([[
process {} {{
    publishDir params.outdir, mode: 'copy'
    container '{}'
    
    memory '{}'
    cpus {}
    time '{}'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path('{}'), emit: {}

    script:
    """
    {}
    """
}}
]], {
    i(1, "PROCESS_NAME"),
    i(2, "biocontainers/tool:version"),
    i(3, "4.GB"),
    i(4, "2"),
    i(5, "2.h"),
    i(6, "output.txt"),
    i(7, "output"),
    i(8, "tool_command --input ${reads} --output output.txt"),
  })),

  -- nf-test block
  s("nftest", fmt([[
nextflow_process {{
    name "Test Process {}"
    script "../main.nf"
    process "{}"

    test("Should run without failures") {{
        when {{
            process {{
                """
                input[0] = {}
                """
            }}
        }}

        then {{
            assert process.success
            assert snapshot(process.out).match()
        }}
    }}
}}
]], {
    i(1, "PROCESS_NAME"),
    rep(1),
    i(2, "[ 'test_sample', file('test_data.txt') ]"),
  })),

  -- Params block
  s("params", fmt([[
params {{
    {} = '{}'
    {} = {}
    {} = null
}}
]], {
    i(1, "input"),
    i(2, "input.txt"),
    i(3, "outdir"),
    i(4, "'results'"),
    i(5, "help"),
  })),
}