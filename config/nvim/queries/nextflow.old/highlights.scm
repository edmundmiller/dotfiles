;; Nextflow treesitter highlight queries
;; Based on the nextflow-io/tree-sitter-nextflow grammar

;; Keywords
[
  "process"
  "workflow" 
  "function"
  "include"
  "from"
  "params"
  "nextflow"
  "manifest"
  "docker"
  "singularity"
  "conda"
  "env"
  "executor"
  "queue"
  "memory"
  "cpus"
  "time"
  "disk"
  "attempt"
  "tag"
  "publishDir"
  "cache"
  "container"
  "module"
  "conda"
  "spack"
  "beforeScript"
  "afterScript"
  "shell"
  "script"
  "exec"
  "stub"
  "when"
  "input"
  "output"
  "take"
  "emit"
  "main"
] @keyword

;; Operators
[
  "="
  "+="
  "-="
  "*="
  "/="
  "%="
  "=="
  "!="
  "<"
  "<="
  ">"
  ">="
  "&&"
  "||"
  "!"
  "+"
  "-"
  "*"
  "/"
  "%"
  "~"
  "=~"
  "!~"
  "<<"
  ">>"
  "&"
  "|"
  "^"
  "?"
  ":"
  "?:"
  "?."
  "*."
  ".&"
  ".@"
  "*.@"
  "++"
  "--"
  "**"
  "<=>"
  "in"
  "as"
  "instanceof"
] @operator

;; Punctuation
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
  ";"
  ","
  "."
  "->"
  "=>"
] @punctuation.delimiter

;; Literals
(boolean_literal) @boolean
(null_literal) @constant.builtin
(number_literal) @number
(string_literal) @string
(gstring_literal) @string
(multiline_string_literal) @string

;; Regular expressions
(regex_literal) @string.regex

;; Comments
(line_comment) @comment
(block_comment) @comment

;; Identifiers
(identifier) @variable

;; Function calls
(method_call
  object: (identifier) @variable
  method: (identifier) @function.method)

(function_call
  function: (identifier) @function.call)

;; Type annotations
(type_annotation
  type: (identifier) @type)

;; Channel operations
(method_call
  object: (identifier) @variable (#match? @variable "^Channel$")
  method: (identifier) @function.builtin)

;; Process directives
(assignment
  left: (identifier) @keyword.directive
  (#match? @keyword.directive "^(cpus|memory|time|disk|queue|container|publishDir|tag|cache|executor|conda|module|beforeScript|afterScript|shell|script|exec|stub|when|input|output)$"))

;; Variable definitions
(assignment
  left: (identifier) @variable.definition)

;; Parameters
(params_declaration
  (identifier) @parameter)

;; Include statements
(include_statement
  module: (string_literal) @string.special)

;; Process names
(process_declaration
  name: (identifier) @function.definition)

;; Workflow names
(workflow_declaration
  name: (identifier) @function.definition)

;; Function names
(function_declaration
  name: (identifier) @function.definition)

;; Groovy-style closures
(closure) @function.definition

;; Error handling
(try_statement) @keyword
(catch_clause) @keyword
(finally_clause) @keyword
(throw_statement) @keyword

;; Control flow
[
  "if"
  "else"
  "while"
  "for"
  "do"
  "switch"
  "case"
  "default"
  "break"
  "continue"
  "return"
  "try"
  "catch"
  "finally"
  "throw"
] @keyword.control

;; Built-in types
[
  "int"
  "long"
  "float"
  "double"
  "boolean"
  "char"
  "byte"
  "short"
  "String"
  "def"
  "var"
  "void"
] @type.builtin

;; Access modifiers
[
  "public"
  "private"
  "protected"
  "static"
  "final"
  "abstract"
  "synchronized"
  "volatile"
  "transient"
  "native"
  "strictfp"
] @keyword.modifier

;; Annotations
(annotation
  name: (identifier) @attribute)

;; Class and interface definitions
(class_declaration
  name: (identifier) @type.definition)
(interface_declaration
  name: (identifier) @type.definition)

;; Import statements
(import_statement) @keyword.import

;; Package declarations
(package_declaration) @keyword.import

;; Special Nextflow variables
((identifier) @constant.builtin
  (#match? @constant.builtin "^(params|workflow|nextflow|launchDir|workDir|projectDir|baseDir)$"))

;; File paths and globs
(string_literal) @string.special
  (#match? @string.special "\\*\\*?|\\?|\\[.*\\]")

;; Environment variables
(gstring_literal
  (gstring_expression
    (identifier) @variable.builtin
    (#match? @variable.builtin "^[A-Z_][A-Z0-9_]*$")))

;; Special method calls
(method_call
  method: (identifier) @function.builtin
  (#match? @function.builtin "^(collect|map|filter|flatten|unique|groupTuple|combine|join|mix|merge|splitText|splitCsv|splitFasta|view|subscribe|into|set)$"))

;; Error highlighting for common mistakes
(ERROR) @error