-- obsidian.nvim — vault: ~/obsidian-vault
-- UI rendering delegated to render-markdown.nvim (see render-markdown.lua)
-- to avoid double-rendering / flicker in Neovide.

local obsidian_project = require 'custom.obsidian_project'
obsidian_project.setup()

return {
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    -- Load on first markdown buffer OR on first <leader>o keystroke,
    -- so global keymaps work from anywhere (dashboard, terminal, etc.).
    event = {
      'BufReadPre ' .. vim.fn.expand '~' .. '/obsidian-vault/**.md',
      'BufNewFile ' .. vim.fn.expand '~' .. '/obsidian-vault/**.md',
    },
    cmd = {
      'Obsidian',
    },
    keys = {
      -- Daily-note workflow (mirrors tmux bind-N / bind-`)
      { '<leader>od', '<cmd>Obsidian today<cr>',         desc = 'Obsidian: today' },
      { '<leader>oD', '<cmd>Obsidian dailies<cr>',       desc = 'Obsidian: browse dailies' },
      { '<leader>ot', '<cmd>Obsidian tomorrow<cr>',      desc = 'Obsidian: tomorrow' },
      { '<leader>oy', '<cmd>Obsidian yesterday<cr>',     desc = 'Obsidian: yesterday' },

      -- Find / search
      { '<leader>of', '<cmd>Obsidian quick_switch<cr>',  desc = 'Obsidian: find note' },
      { '<leader>og', '<cmd>Obsidian search<cr>',        desc = 'Obsidian: grep notes' },
      { '<leader>oT', '<cmd>Obsidian tags<cr>',          desc = 'Obsidian: search tags' },

      -- Create / manipulate
      { '<leader>on', '<cmd>Obsidian new<cr>',           desc = 'Obsidian: new note' },
      { '<leader>oN', '<cmd>Obsidian new_from_template<cr>', desc = 'Obsidian: new from template' },
      { '<leader>oi', '<cmd>Obsidian template<cr>',      desc = 'Obsidian: insert template' },
      { '<leader>ol', '<cmd>Obsidian link<cr>',          desc = 'Obsidian: insert link', mode = { 'n', 'v' } },
      { '<leader>oL', '<cmd>Obsidian link_new<cr>',      desc = 'Obsidian: link to new note', mode = { 'v' } },
      { '<leader>or', '<cmd>Obsidian rename<cr>',        desc = 'Obsidian: rename (link-safe)' },
      { '<leader>ob', '<cmd>Obsidian backlinks<cr>',     desc = 'Obsidian: backlinks' },

      -- Vault entry points
      { '<leader>oh', function()
          vim.cmd('edit ' .. vim.fn.expand '~/obsidian-vault/README.md')
        end, desc = 'Obsidian: vault home' },
      { '<leader>op', obsidian_project.open_current_project_note, desc = 'Obsidian: current project note' },
      { '<leader>oo', '<cmd>Obsidian open<cr>',          desc = 'Obsidian: open in app (graph etc.)' },
      { '<leader>oP', '<cmd>Obsidian paste_img<cr>',     desc = 'Obsidian: paste image' },
    },
    init = function()
      -- conceallevel must be 1+ for obsidian.nvim link/checkbox handling,
      -- and 2 is what render-markdown.nvim wants. Apply globally to markdown.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'markdown',
        callback = function()
          vim.opt_local.conceallevel = 2
        end,
      })
      -- Also fire for the current buffer (init runs inside the FileType hook
      -- that triggered the plugin load).
      vim.opt_local.conceallevel = 2
    end,
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
      legacy_commands = false,

      workspaces = {
        {
          name = 'personal',
          path = '~/obsidian-vault',
        },
      },

      -- Pickers / completion
      picker = { name = 'telescope.nvim' },
      search = {
        sort_by = 'modified',
        sort_reversed = true,
      },
      open_notes_in = 'current',

      -- blink.cmp is auto-detected; explicit for clarity
      completion = {
        blink = true,
        min_chars = 2,
      },

      -- Daily notes
      daily_notes = {
        folder = '00_Inbox/Daily',
        date_format = '%Y-%m-%d',
        alias_format = '%B %-d, %Y',
        template = 'Daily Note Template.md',
        workdays_only = false,
      },

      -- Templates folder (matches existing vault layout)
      templates = {
        folder = '07_Metadata/Templates',
        date_format = '%Y-%m-%d',
        time_format = '%H:%M',
      },

      -- Drop new notes into the inbox instead of the vault root.
      -- Fixes the stray `YYYY-MM-DD.md` files showing up alongside README.md.
      new_notes_location = 'notes_subdir',
      notes_subdir = '00_Inbox',

      -- Pasted/dropped images land here, matching the existing folder.
      attachments = {
        folder = '06_Attachments',
      },

      -- Checkbox cycling order — used by both `Obsidian toggle_checkbox`
      -- and the buffer-local <leader>ch keymap below.
      checkbox = {
        order = { ' ', 'x', '>', '~', '!' },
      },

      link = { style = 'wiki' },

      -- Slugify note IDs from the title; fall back to a timestamp.
      note_id_func = function(title)
        if title ~= nil and title ~= '' then
          return title:gsub(' ', '-'):gsub('[^A-Za-z0-9-]', ''):lower()
        else
          return tostring(os.time())
        end
      end,

      -- Buffer-local keymaps applied to every note in the vault.
      callbacks = {
        enter_note = function(note)
          local buf = (note and note.bufnr) or 0
          local map = function(mode, lhs, rhs, desc, expr)
            vim.keymap.set(mode, lhs, rhs, { buffer = buf, expr = expr or false, desc = desc })
          end
          map('n', '<CR>', function() return require('obsidian').util.smart_action() end,
            'Obsidian: follow link / toggle checkbox', true)
          map('n', ']o', function() return require('obsidian').util.nav_link 'next' end,
            'Obsidian: next link', true)
          map('n', '[o', function() return require('obsidian').util.nav_link 'prev' end,
            'Obsidian: prev link', true)
          map('n', '<leader>oc', '<cmd>Obsidian toggle_checkbox<cr>',
            'Obsidian: cycle checkbox')
        end,
      },

      -- Let render-markdown.nvim handle visuals — disabling here prevents the
      -- double-render flicker that's especially noticeable in Neovide.
      ui = { enable = false },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
