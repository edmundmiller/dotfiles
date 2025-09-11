;; Neotest queries for nf-test files using Nextflow treesitter parser

;; Match nextflow_process test blocks
(function_call
  function: (identifier) @func_name (#eq? @func_name "nextflow_process")
  arguments: (argument_list
    (closure
      (block
        (expression_statement
          (function_call
            function: (field_access
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (argument_list
              (string_literal) @test.name
              (closure) @test.definition
            )
          )
        )
      )*
    )
  )
) @test.process

;; Match nextflow_workflow test blocks
(function_call
  function: (identifier) @func_name (#eq? @func_name "nextflow_workflow")
  arguments: (argument_list
    (closure
      (block
        (expression_statement
          (function_call
            function: (field_access
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (argument_list
              (string_literal) @test.name
              (closure) @test.definition
            )
          )
        )
      )*
    )
  )
) @test.workflow

;; Match nextflow_pipeline test blocks
(function_call
  function: (identifier) @func_name (#eq? @func_name "nextflow_pipeline")
  arguments: (argument_list
    (closure
      (block
        (expression_statement
          (function_call
            function: (field_access
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (argument_list
              (string_literal) @test.name
              (closure) @test.definition
            )
          )
        )
      )*
    )
  )
) @test.pipeline

;; Match nextflow_function test blocks
(function_call
  function: (identifier) @func_name (#eq? @func_name "nextflow_function")
  arguments: (argument_list
    (closure
      (block
        (expression_statement
          (function_call
            function: (field_access
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (argument_list
              (string_literal) @test.name
              (closure) @test.definition
            )
          )
        )
      )*
    )
  )
) @test.function

;; Match test blocks with assignment for namespace-like organization
(assignment
  left: (identifier) @namespace.name
  right: (function_call
    function: (identifier) @func_name (#match? @func_name "^nextflow_(process|workflow|pipeline|function)$")
    arguments: (argument_list
      (closure) @namespace.definition
    )
  )
) @namespace