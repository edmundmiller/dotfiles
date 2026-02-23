-- https://github.com/MeanderingProgrammer/render-markdown.nvim
-- Beautiful in-buffer markdown rendering: headings, checkboxes, code blocks, links

return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  ft = { 'markdown' },
  opts = {
    bullet = {
      enabled = true,
    },
    checkbox = {
      enabled = true,
      position = 'inline',
      unchecked = {
        icon = '   󰄱 ',
        highlight = 'RenderMarkdownUnchecked',
      },
      checked = {
        icon = '   󰱒 ',
        highlight = 'RenderMarkdownChecked',
      },
    },
    html = {
      enabled = true,
      comment = { conceal = false },
    },
    link = {
      image = '󰥶 ',
    },
    heading = {
      sign = false,
      icons = { '󰎤 ', '󰎧 ', '󰎪 ', '󰎭 ', '󰎱 ', '󰎳 ' },
    },
    code = {
      -- 'full' renders the language label + border; 'normal' just background
      style = 'full',
    },
  },
}
