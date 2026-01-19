-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Configure core features of AstroNvim
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = true, -- enable autopairs at start
      cmp = true, -- enable completion at start
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Rooter: Auto-CD to project root
    rooter = {
      enabled = true,
      autochdir = true, -- Auto-CD on BufEnter
      detector = {
        "lsp",
        { ".git", "_darcs", ".hg", ".bzr", ".svn" },
        { "lua", "Makefile", "package.json", "pyproject.toml", "Cargo.toml" },
      },
      scope = "global",
      notify = false,
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        relativenumber = true, -- sets vim.opt.relativenumber
        number = true, -- sets vim.opt.number
        spell = false, -- sets vim.opt.spell
        signcolumn = "yes", -- sets vim.opt.signcolumn to yes
        wrap = false, -- sets vim.opt.wrap
      },
      g = { -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
      },
    },
    -- Mappings can be configured through AstroCore as well.
    -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
    mappings = {
      -- first key is the mode
      n = {
        -- === DOOM EMACS KEYBINDINGS ===

        -- Project search
        ["<Leader><Leader>"] = { function() require("telescope.builtin").find_files({ hidden = true }) end, desc = "Find files" },
        ["<Leader>."] = { function() require("oil").open() end, desc = "Open directory in oil" },
        ["<Leader>,"] = { function() require("telescope.builtin").buffers() end, desc = "Switch buffer" },

        -- File operations
        ["<Leader>f"] = { desc = "Files" },
        ["<Leader>ff"] = { function() require("telescope.builtin").find_files({ hidden = true }) end, desc = "Find file" },
        ["<Leader>fr"] = { function() require("telescope.builtin").oldfiles() end, desc = "Recent files" },
        ["<Leader>fs"] = { "<cmd>w<cr>", desc = "Save file" },
        ["<Leader>fS"] = { "<cmd>wa<cr>", desc = "Save all files" },
        ["<Leader>ft"] = { "<cmd>Neotree toggle<cr>", desc = "Toggle file tree" },
        ["<Leader>fR"] = { function() vim.lsp.buf.rename() end, desc = "Rename file" },
        ["<Leader>fD"] = { "<cmd>call delete(expand('%')) | bdelete!<cr>", desc = "Delete file" },

        -- Search
        ["<Leader>s"] = { desc = "Search" },
        ["<Leader>ss"] = { function() require("telescope.builtin").current_buffer_fuzzy_find() end, desc = "Search buffer" },
        ["<Leader>sp"] = { function() require("telescope.builtin").live_grep() end, desc = "Search project" },
        ["<Leader>sP"] = { function() require("telescope.builtin").grep_string() end, desc = "Search project for word" },
        ["<Leader>sb"] = { function() require("telescope.builtin").buffers() end, desc = "Search buffers" },
        ["<Leader>sh"] = { function() require("telescope.builtin").help_tags() end, desc = "Search help" },
        ["<Leader>sm"] = { function() require("telescope.builtin").marks() end, desc = "Search marks" },
        ["<Leader>sr"] = { function() require("telescope.builtin").resume() end, desc = "Resume search" },
        ["<Leader>sc"] = { function() require("telescope.builtin").commands() end, desc = "Search commands" },
        ["<Leader>sk"] = { function() require("telescope.builtin").keymaps() end, desc = "Search keymaps" },

        -- Buffers
        ["<Leader>b"] = { desc = "Buffers" },
        ["<Leader>bb"] = { function() require("telescope.builtin").buffers() end, desc = "Switch buffer" },
        ["<Leader>bd"] = { function() require("astrocore.buffer").close() end, desc = "Delete buffer" },
        ["<Leader>bD"] = { function() require("astrocore.buffer").close(0, true) end, desc = "Delete buffer (force)" },
        ["<Leader>bn"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["<Leader>bp"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
        ["<Leader>bl"] = { function() require("telescope.builtin").buffers() end, desc = "List buffers" },
        ["<Leader>bs"] = { "<cmd>w<cr>", desc = "Save buffer" },
        ["<Leader>bS"] = { "<cmd>wa<cr>", desc = "Save all buffers" },
        ["<Leader>bc"] = { function() require("astrocore.buffer").close_all() end, desc = "Close all buffers" },
        ["<Leader>bC"] = { function() require("astrocore.buffer").close_all(true) end, desc = "Close all buffers (force)" },

        -- Windows
        ["<Leader>w"] = { desc = "Windows" },
        ["<Leader>ww"] = { "<C-w>w", desc = "Other window" },
        ["<Leader>wd"] = { "<C-w>c", desc = "Delete window" },
        ["<Leader>w-"] = { "<C-w>s", desc = "Split window below" },
        ["<Leader>w|"] = { "<C-w>v", desc = "Split window right" },
        ["<Leader>ws"] = { "<C-w>s", desc = "Split window below" },
        ["<Leader>wv"] = { "<C-w>v", desc = "Split window right" },
        ["<Leader>wh"] = { "<C-w>h", desc = "Window left" },
        ["<Leader>wj"] = { "<C-w>j", desc = "Window below" },
        ["<Leader>wl"] = { "<C-w>l", desc = "Window right" },
        ["<Leader>wk"] = { "<C-w>k", desc = "Window above" },
        ["<Leader>wH"] = { "<C-w>5<", desc = "Decrease window width" },
        ["<Leader>wJ"] = { "<C-w>5+", desc = "Increase window height" },
        ["<Leader>wK"] = { "<C-w>5-", desc = "Decrease window height" },
        ["<Leader>wL"] = { "<C-w>5>", desc = "Increase window width" },
        ["<Leader>w="] = { "<C-w>=", desc = "Balance windows" },
        ["<Leader>wo"] = { "<C-w>o", desc = "Only window" },

        -- Git
        ["<Leader>g"] = { desc = "Git" },
        ["<Leader>gg"] = { function() require("neogit").open() end, desc = "Git status" },
        ["<Leader>gb"] = { function() require("telescope.builtin").git_branches() end, desc = "Git branches" },
        ["<Leader>gc"] = { function() require("telescope.builtin").git_commits() end, desc = "Git commits" },
        ["<Leader>gC"] = { function() require("telescope.builtin").git_bcommits() end, desc = "Git buffer commits" },
        ["<Leader>gd"] = { function() require("diffview").open() end, desc = "Git diff" },
        ["<Leader>gH"] = { function() require("diffview").file_history() end, desc = "Git file history" },
        ["<Leader>gl"] = { function() vim.cmd("Git log --oneline") end, desc = "Git log" },
        ["<Leader>gf"] = { function() require("telescope.builtin").git_files() end, desc = "Git files" },
        ["<Leader>gs"] = { function() require("telescope.builtin").git_status() end, desc = "Git status (telescope)" },

        -- Code navigation
        ["<Leader>c"] = { desc = "Code" },
        ["<Leader>cd"] = { function() vim.lsp.buf.definition() end, desc = "Go to definition" },
        ["<Leader>cD"] = { function() vim.lsp.buf.declaration() end, desc = "Go to declaration" },
        ["<Leader>ci"] = { function() vim.lsp.buf.implementation() end, desc = "Go to implementation" },
        ["<Leader>ct"] = { function() vim.lsp.buf.type_definition() end, desc = "Go to type definition" },
        ["<Leader>cr"] = { function() vim.lsp.buf.references() end, desc = "Find references" },
        ["<Leader>ca"] = { function() vim.lsp.buf.code_action() end, desc = "Code action" },
        ["<Leader>cf"] = { function() vim.lsp.buf.format() end, desc = "Format buffer" },
        ["<Leader>cR"] = { function() vim.lsp.buf.rename() end, desc = "Rename symbol" },

        -- Toggle
        ["<Leader>t"] = { desc = "Toggle" },
        ["<Leader>tn"] = { "<cmd>set number!<cr>", desc = "Toggle line numbers" },
        ["<Leader>tr"] = { "<cmd>set relativenumber!<cr>", desc = "Toggle relative numbers" },
        ["<Leader>tw"] = { "<cmd>set wrap!<cr>", desc = "Toggle word wrap" },
        ["<Leader>ts"] = { "<cmd>set spell!<cr>", desc = "Toggle spell check" },
        ["<Leader>th"] = { "<cmd>set hlsearch!<cr>", desc = "Toggle search highlight" },
        ["<Leader>tt"] = { "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
        ["<Leader>tz"] = { function() require("zen-mode").toggle() end, desc = "Toggle zen mode" },

        -- Quit
        ["<Leader>q"] = { desc = "Quit" },
        ["<Leader>qq"] = { "<cmd>qa<cr>", desc = "Quit all" },
        ["<Leader>qQ"] = { "<cmd>qa!<cr>", desc = "Quit all (force)" },
        ["<Leader>qs"] = { "<cmd>xa<cr>", desc = "Save all and quit" },

        -- Help
        ["<Leader>h"] = { desc = "Help" },
        ["<Leader>hh"] = { function() require("telescope.builtin").help_tags() end, desc = "Help tags" },
        ["<Leader>hm"] = { function() require("telescope.builtin").man_pages() end, desc = "Man pages" },
        ["<Leader>hk"] = { function() require("telescope.builtin").keymaps() end, desc = "Keymaps" },
        ["<Leader>hc"] = { function() require("telescope.builtin").commands() end, desc = "Commands" },

        -- navigate buffer tabs (keep original AstroNvim bindings)
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },
      },

      -- Visual mode mappings
      v = {
        -- Code actions in visual mode
        ["<Leader>ca"] = { function() vim.lsp.buf.code_action() end, desc = "Code action" },
        ["<Leader>cf"] = { function() vim.lsp.buf.format() end, desc = "Format selection" },
      },
    },
  },
}
