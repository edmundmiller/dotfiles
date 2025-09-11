;; Nextflow treesitter indent queries

[
  (process_declaration)
  (workflow_declaration)
  (function_declaration)
  (class_declaration)
  (interface_declaration)
  (method_declaration)
  (closure)
  (block)
  (class_body)
  (interface_body)
  (switch_block)
  (if_statement)
  (while_statement)
  (for_statement)
  (try_statement)
  (catch_clause)
  (finally_clause)
  (case_clause)
  (array_literal)
  (map_literal)
  (argument_list)
  (parameter_list)
] @indent.begin

[
  "}"
  "]"
  ")"
] @indent.end

[
  (line_comment)
  (block_comment)
] @indent.ignore