return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    init = function()
      vim.api.nvim_create_user_command('ToggleFormatter', function()
        vim.b.disable_autoformat = not vim.b.disable_autoformat
        vim.notify('Format on save ' .. (vim.b.disable_autoformat and 'disabled' or 'enabled') .. ' for this buffer')
      end, { desc = 'Toggle format on save for this buffer' })
    end,
    keys = {
      { '<leader>tf', '<cmd>ToggleFormatter<CR>', desc = '[T]oggle [F]ormat on save (buffer)' },
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        if vim.b[bufnr].disable_autoformat then return nil end
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        markdown = { 'oxfmt' },
        ['markdown.mdx'] = { 'oxfmt' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { 'oxfmt' },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
