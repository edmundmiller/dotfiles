;; Tree-sitter tags queries for Nextflow
;; These patterns define how to extract symbols for code navigation and outline views

;; ========================================
;; DEFINITIONS - Main Nextflow Constructs
;; ========================================

;; Process definitions
(process_definition
  name: (identifier) @name) @definition.method

;; Workflow definitions
(workflow_definition
  name: (identifier) @name) @definition.function

;; Function declarations
(function_declaration
  name: (identifier) @name) @definition.function

;; Parameter declarations (workflow inputs)
(parameter
  name: (identifier) @name) @definition.variable

;; ========================================
;; REFERENCES - Usage and Calls
;; ========================================

;; Process invocations within workflows
(simple_statement
  (identifier) @name) @reference.call

;; Method calls on channels and objects
(method_call
  method: (identifier) @name) @reference.call

;; Function calls
(function_call
  function: (identifier) @name) @reference.call

;; Include statements (importing other Nextflow modules)
(include_statement
  source: (string_literal) @name) @reference.implementation
