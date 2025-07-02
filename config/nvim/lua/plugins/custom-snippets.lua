-- Custom snippets for Nextflow and Typst development
return {
  -- Custom LuaSnip configuration
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
    opts = {
      history = true,
      delete_check_events = "TextChanged",
    },
    config = function(_, opts)
      local ls = require("luasnip")
      ls.setup(opts)
      
      -- Load custom snippets
      require("luasnip.loaders.from_lua").load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
      
      -- Load friendly-snippets
      require("luasnip.loaders.from_vscode").lazy_load()
      
      -- Custom keybindings for snippets
      vim.keymap.set({ "i" }, "<C-K>", function() ls.expand() end, { silent = true, desc = "Expand snippet" })
      vim.keymap.set({ "i", "s" }, "<C-L>", function() ls.jump(1) end, { silent = true, desc = "Jump forward" })
      vim.keymap.set({ "i", "s" }, "<C-J>", function() ls.jump(-1) end, { silent = true, desc = "Jump backward" })
      
      vim.keymap.set({ "i", "s" }, "<C-E>", function()
        if ls.choice_active() then
          ls.change_choice(1)
        end
      end, { silent = true, desc = "Change choice" })
    end,
  },
}