-- https://github.com/HakonHarnes/img-clip.nvim
-- Paste images from clipboard directly into markdown (requires imagemagick)

return {
  'HakonHarnes/img-clip.nvim',
  event = 'VeryLazy',
  opts = {
    default = {
      -- Store relative to file (not cwd), no absolute paths
      use_absolute_path = false,
      relative_to_current_file = true,

      -- Folder named after the current file, e.g. my-note-img/
      dir_path = function()
        return vim.fn.expand '%:t:r' .. '-img'
      end,

      -- Auto-name by timestamp, no prompt
      prompt_for_file_name = false,
      file_name = '%y%m%d-%H%M%S',

      -- Convert to avif at 75% quality (smaller than png/jpg)
      -- Requires: brew install imagemagick
      extension = 'avif',
      process_cmd = 'convert - -quality 75 avif:-',
    },

    filetypes = {
      markdown = {
        url_encode_path = true,
        -- ./ prefix lets blink.cmp LSP find images by path
        template = '![Image](./$FILE_PATH)',
      },
    },
  },

  keys = {
    { '<leader>ip', '<cmd>PasteImage<cr>', desc = '[I]mage [P]aste from clipboard' },
  },
}
