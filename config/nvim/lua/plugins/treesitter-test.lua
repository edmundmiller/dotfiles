-- Tree-sitter-test grammar support
-- Requires: npm install -g tree-sitter-cli
return {
  {
    "tree-sitter-grammars/tree-sitter-test",
    build = "mkdir parser && tree-sitter build -o parser/test.so",
    ft = "test",
    init = function()
      -- toggle full-width rules for test separators
      vim.g.tstest_fullwidth_rules = false
      -- set the highlight group of the rules
      vim.g.tstest_rule_hlgroup = "FoldColumn"
    end,
  },
}