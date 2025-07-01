;; Neotest queries for nf-test (Groovy-based test files)

;; Match nextflow_process test blocks
(call_expression
  function: (identifier) @func_name (#eq? @func_name "nextflow_process")
  arguments: (arguments
    (closure
      body: (statements
        (expression_statement
          (call_expression
            function: (field_expression
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (arguments
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
(call_expression
  function: (identifier) @func_name (#eq? @func_name "nextflow_workflow")
  arguments: (arguments
    (closure
      body: (statements
        (expression_statement
          (call_expression
            function: (field_expression
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (arguments
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
(call_expression
  function: (identifier) @func_name (#eq? @func_name "nextflow_pipeline")
  arguments: (arguments
    (closure
      body: (statements
        (expression_statement
          (call_expression
            function: (field_expression
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (arguments
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
(call_expression
  function: (identifier) @func_name (#eq? @func_name "nextflow_function")
  arguments: (arguments
    (closure
      body: (statements
        (expression_statement
          (call_expression
            function: (field_expression
              object: (identifier)
              field: (identifier) @test_method (#eq? @test_method "test")
            )
            arguments: (arguments
              (string_literal) @test.name
              (closure) @test.definition
            )
          )
        )
      )*
    )
  )
) @test.function

;; Match test blocks with names for namespace-like organization
(assignment_expression
  left: (identifier) @namespace.name
  right: (call_expression
    function: (identifier) @func_name (#match? @func_name "^nextflow_(process|workflow|pipeline|function)$")
    arguments: (arguments
      (closure) @namespace.definition
    )
  )
) @namespace