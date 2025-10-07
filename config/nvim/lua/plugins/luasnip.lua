-- Custom LuaSnip configuration for snippets
return {
  {
    "L3MON4D3/LuaSnip",
    build = (function()
      -- Build Step is needed for regex support in snippets
      -- This step is not supported in many windows environments
      -- Remove the below condition to re-enable on windows
      if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
        return
      end
      return "make install_jsregexp"
    end)(),
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    opts = function(_, opts)
      -- Extend AstroNvim's default opts
      opts.history = true
      opts.delete_check_events = "TextChanged"
      return opts
    end,
    config = function(plugin, opts)
      -- First run AstroNvim's default LuaSnip config
      require("astronvim.plugins.configs.luasnip")(plugin, opts)

      local ls = require("luasnip")

      -- Load custom Lua snippets from config/snippets directory
      require("luasnip.loaders.from_lua").load({
        paths = { vim.fn.stdpath("config") .. "/snippets" }
      })

      -- Load friendly-snippets (VSCode format)
      require("luasnip.loaders.from_vscode").lazy_load()

      -- Custom keybindings for snippets
      vim.keymap.set({ "i" }, "<C-K>", function()
        ls.expand()
      end, { silent = true, desc = "Expand snippet" })

      vim.keymap.set({ "i", "s" }, "<C-L>", function()
        ls.jump(1)
      end, { silent = true, desc = "Jump forward in snippet" })

      vim.keymap.set({ "i", "s" }, "<C-J>", function()
        ls.jump(-1)
      end, { silent = true, desc = "Jump backward in snippet" })

      vim.keymap.set({ "i", "s" }, "<C-E>", function()
        if ls.choice_active() then
          ls.change_choice(1)
        end
      end, { silent = true, desc = "Cycle snippet choices" })
    end,
  },
}
