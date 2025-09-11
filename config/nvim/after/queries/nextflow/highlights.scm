;; Most minimal possible Nextflow highlighting
;; Only basic node types without any fields

;; Comments
(line_comment) @comment
(block_comment) @comment

;; Literals
(string_literal) @string
(integer_literal) @number
(boolean_literal) @boolean

;; All identifiers
(identifier) @variable

;; Process and workflow definitions (without field access)
(process_definition) @function
(workflow_definition) @function