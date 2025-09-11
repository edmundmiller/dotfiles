;; Language injection queries for Nextflow
;; These queries tell tree-sitter to re-parse script content as bash/shell

;; Inject bash syntax into script_content nodes (new grammar structure)
((script_content) @injection.content
 (#set! injection.language "bash"))

;; Inject bash into string literals within script declarations
((script_declaration
   (script_content
     (string_literal) @injection.content))
 (#set! injection.language "bash"))

;; Inject bash into triple-quoted strings within script declarations
((script_declaration
   (script_content
     (triple_quoted_string) @injection.content))
 (#set! injection.language "bash"))

;; Handle shebang lines specifically as bash
((script_content) @injection.content
 (#match? @injection.content "^\\s*#!/.*bash")
 (#set! injection.language "bash"))

;; Handle shell scripts with shell shebang
((script_content) @injection.content
 (#match? @injection.content "^\\s*#!/.*sh")
 (#set! injection.language "bash"))

;; Fallback patterns for common shell constructs
((script_content) @injection.content
 (#match? @injection.content "echo\\s")
 (#set! injection.language "bash"))
