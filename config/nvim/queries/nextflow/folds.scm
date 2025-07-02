;; Nextflow treesitter fold queries

;; Fold process blocks
(process_declaration
  body: (block) @fold)

;; Fold workflow blocks  
(workflow_declaration
  body: (block) @fold)

;; Fold function blocks
(function_declaration
  body: (block) @fold)

;; Fold class and interface blocks
(class_declaration
  body: (class_body) @fold)
(interface_declaration
  body: (interface_body) @fold)

;; Fold method blocks
(method_declaration
  body: (block) @fold)

;; Fold closure blocks
(closure
  body: (block) @fold)

;; Fold control flow blocks
(if_statement
  then: (block) @fold)
(if_statement
  else: (block) @fold)
(while_statement
  body: (block) @fold)
(for_statement
  body: (block) @fold)
(try_statement
  body: (block) @fold)
(catch_clause
  body: (block) @fold)
(finally_clause
  body: (block) @fold)

;; Fold multi-line comments
(block_comment) @fold

;; Fold multiline strings
(multiline_string_literal) @fold

;; Fold array and map literals
(array_literal) @fold
(map_literal) @fold

;; Fold switch statements
(switch_statement
  body: (switch_block) @fold)

;; Fold case blocks
(case_clause
  body: (block) @fold)