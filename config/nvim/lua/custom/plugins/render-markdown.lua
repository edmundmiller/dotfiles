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
      -- tokyonight auto-generates these via groups/render-markdown.lua
      -- using its rainbow palette at 10% bg blend
      backgrounds = {
        'RenderMarkdownH1Bg', 'RenderMarkdownH2Bg', 'RenderMarkdownH3Bg',
        'RenderMarkdownH4Bg', 'RenderMarkdownH5Bg', 'RenderMarkdownH6Bg',
      },
      foregrounds = {
        'RenderMarkdownH1Fg', 'RenderMarkdownH2Fg', 'RenderMarkdownH3Fg',
        'RenderMarkdownH4Fg', 'RenderMarkdownH5Fg', 'RenderMarkdownH6Fg',
      },
    },
    code = {
      -- 'full' renders the language label + border; 'normal' just background
      style = 'full',
    },
  },
}
