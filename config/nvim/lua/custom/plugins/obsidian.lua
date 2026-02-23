return {
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    ft = 'markdown',
    -- lazy.nvim keys (global, plugin loaded on first use)
    -- mirrors tmux bind-N / bind-` daily-note workflow
    keys = {
      { '<leader>od', '<cmd>Obsidian today<CR>', desc = 'Obsidian: today\'s daily note' },
      { '<leader>ot', '<cmd>Obsidian tomorrow<CR>', desc = 'Obsidian: tomorrow\'s note' },
      { '<leader>oy', '<cmd>Obsidian yesterday<CR>', desc = 'Obsidian: yesterday\'s note' },
      { '<leader>of', '<cmd>Obsidian quick_switch<CR>', desc = 'Obsidian: find note' },
      { '<leader>og', '<cmd>Obsidian search<CR>', desc = 'Obsidian: grep notes' },
      { '<leader>on', '<cmd>Obsidian new<CR>', desc = 'Obsidian: new note' },
    },
    init = function()
      -- Set conceallevel for all future markdown buffers
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'markdown',
        callback = function()
          vim.opt_local.conceallevel = 2
        end,
      })
      -- Also apply immediately — init fires inside the FileType handler so
      -- opt_local affects the buffer that triggered the plugin load
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

      picker = { name = 'telescope.nvim' },

      daily_notes = {
        folder = '00_Inbox/Daily',
        date_format = '%Y-%m-%d',
      },

      -- blink.cmp is auto-detected; explicit for clarity
      completion = {
        blink = true,
        min_chars = 2,
      },

      -- Checkbox cycling order
      checkbox = {
        order = { ' ', 'x', '>', '~', '!' },
      },

      -- Buffer-local keymaps set on each note enter
      callbacks = {
        enter_note = function()
          vim.keymap.set('n', '<CR>', function()
            return require('obsidian').util.smart_action()
          end, { buffer = true, expr = true, desc = 'Obsidian: follow link' })
          vim.keymap.set('n', '[o', function()
            return require('obsidian').util.nav_link 'prev'
          end, { buffer = true, expr = true, desc = 'Obsidian: prev link' })
          vim.keymap.set('n', ']o', function()
            return require('obsidian').util.nav_link 'next'
          end, { buffer = true, expr = true, desc = 'Obsidian: next link' })
        end,
      },

      note_id_func = function(title)
        if title ~= nil then
          return title:gsub(' ', '-'):gsub('[^A-Za-z0-9-]', ''):lower()
        else
          return tostring(os.time())
        end
      end,

      preferred_link_style = 'wiki',

      ui = {
        enable = true,
        checkboxes = {
          [' '] = { char = '󰄱', hl_group = 'ObsidianTodo' },
          ['x'] = { char = '', hl_group = 'ObsidianDone' },
          ['>'] = { char = '', hl_group = 'ObsidianRightArrow' },
          ['~'] = { char = '󰰱', hl_group = 'ObsidianTilde' },
          ['!'] = { char = '', hl_group = 'ObsidianImportant' },
        },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
