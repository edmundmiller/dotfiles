-- Resession: Session management
-- Auto-saves per directory, auto-restores on nvim startup
-- Commands: <Leader>SS (save), <Leader>S. (load), <Leader>Sl (last), <Leader>Sd (delete)

return {
  "stevearc/resession.nvim",
  opts = function(_, opts)
    local resession = require("resession")

    opts.autosave = {
      enabled = true,
      interval = 60,
      notify = false,
    }

    -- Auto-save session on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = function()
        local cwd = vim.fn.getcwd()
        resession.save(cwd, { notify = false })
      end,
    })

    -- Auto-restore session on startup (only if no arguments)
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        if vim.fn.argc(-1) == 0 then
          local cwd = vim.fn.getcwd()
          resession.load(cwd, { silence_errors = true })
        end
      end,
      nested = true,
    })

    return opts
  end,
}
