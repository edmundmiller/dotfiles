-- Image utilities for markdown workflows
-- Adapted from https://github.com/linkarzu/dotfiles-latest
-- keymaps/keymaps.lua (image section, ~line 1057-1952)
--
-- Keymaps:
--   <M-a>       paste image using standard img-clip settings (filename-img/ dir)
--   <M-1>       paste image into assets/ directory (blog/reusable workflow)
--   <leader>id  delete image file under cursor (uses trash CLI)
--   <leader>iR  rename image under cursor + update references in file
--   <leader>if  open image under cursor in Finder
--   <leader>io  open image under cursor in Preview

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Extract the image path from the markdown link on the current line
local function get_image_path()
  local line = vim.api.nvim_get_current_line()
  local _, _, path = string.find(line, '%[.-%]%((.-)%)')
  return path
end

-- ---------------------------------------------------------------------------
-- Assets-directory config
-- ---------------------------------------------------------------------------
-- Subdirectory inside assets/ where images land.
-- Change to e.g. "" to store directly in assets/
local IMAGE_STORAGE_PATH = 'img/imgs'

-- Walk up from the current file's directory looking for assets/<IMAGE_STORAGE_PATH>
local function find_assets_dir()
  local dir = vim.fn.expand '%:p:h'
  while dir ~= '/' do
    local full = dir .. '/assets/' .. IMAGE_STORAGE_PATH
    if vim.fn.isdirectory(full) == 1 then
      return full
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- <M-a>  Standard img-clip paste (uses global img-clip.nvim settings)
-- ---------------------------------------------------------------------------
vim.keymap.set({ 'n', 'i' }, '<M-a>', function()
  local pasted = require('img-clip').paste_image()
  if pasted then
    vim.cmd 'silent! update'
    local line = vim.api.nvim_get_current_line()
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], #line })
    vim.cmd 'edit!'
  end
end, { desc = '[I]mage paste (standard img-clip settings)' })

-- ---------------------------------------------------------------------------
-- <M-1>  Paste image into assets/ directory
-- ---------------------------------------------------------------------------
local function paste_to_assets(img_dir)
  -- Helper: call img-clip with explicit dir/name/ext
  local function do_paste(dir_path, file_name, ext, cmd)
    return require('img-clip').paste_image {
      dir_path = dir_path,
      use_absolute_path = false,
      relative_to_current_file = false,
      file_name = file_name,
      extension = ext or 'avif',
      process_cmd = cmd or 'convert - -quality 75 avif:-',
    }
  end

  local prefix = vim.fn.strftime '%y%m%d-'

  local function prompt_name(callback)
    vim.ui.input({ prompt = 'Image name (no spaces), prefix: ' .. prefix }, function(input)
      if not input or input == '' or input:match '%s' then
        vim.notify('Cancelled', vim.log.levels.WARN)
        return
      end
      local full_name = prefix .. input
      local file_path = img_dir .. '/' .. full_name .. '.avif'
      if vim.fn.filereadable(file_path) == 1 then
        vim.notify('Name already exists, try again.', vim.log.levels.WARN)
        prompt_name(callback)
        return
      end
      callback(full_name)
    end)
  end

  -- Optional format override
  vim.ui.select({ 'avif (default)', 'webp', 'png', 'jpg', 'cancel' }, {
    prompt = 'Image format:',
  }, function(choice)
    if not choice or choice == 'cancel' then
      return
    end
    local ext = choice == 'avif (default)' and 'avif' or choice
    local process_cmd = 'convert - -quality 75 ' .. ext .. ':-'

    prompt_name(function(full_name)
      if do_paste(img_dir, full_name, ext, process_cmd) then
        vim.cmd 'silent! update'
        vim.cmd 'edit!'
        vim.notify('Image saved to assets: ' .. full_name .. '.' .. ext, vim.log.levels.INFO)
      else
        vim.notify('No image in clipboard or paste failed.', vim.log.levels.WARN)
      end
    end)
  end)
end

vim.keymap.set({ 'n', 'i' }, '<M-1>', function()
  local img_dir = find_assets_dir()
  if not img_dir then
    vim.ui.select({ 'yes', 'no' }, {
      prompt = IMAGE_STORAGE_PATH .. ' not found. Create assets/' .. IMAGE_STORAGE_PATH .. '?',
    }, function(choice)
      if choice == 'yes' then
        img_dir = vim.fn.getcwd() .. '/assets/' .. IMAGE_STORAGE_PATH
        vim.fn.mkdir(img_dir, 'p')
        vim.defer_fn(function()
          paste_to_assets(img_dir)
        end, 100)
      end
    end)
    return
  end
  paste_to_assets(img_dir)
end, { desc = "[I]mage paste to 'assets/' directory" })

-- ---------------------------------------------------------------------------
-- <leader>id  Delete image file under cursor (moves to trash)
-- ---------------------------------------------------------------------------
vim.keymap.set('n', '<leader>id', function()
  local image_path = get_image_path()
  if not image_path then
    vim.api.nvim_echo({ { 'No image found under cursor', 'WarningMsg' } }, false, {})
    return
  end
  if image_path:sub(1, 4) == 'http' then
    vim.api.nvim_echo({ { 'URL images cannot be deleted from disk.', 'WarningMsg' } }, false, {})
    return
  end

  local abs = vim.fn.expand '%:p:h' .. '/' .. image_path
  if vim.fn.filereadable(abs) == 0 then
    vim.api.nvim_echo({ { 'File not found:\n' .. abs, 'ErrorMsg' } }, false, {})
    return
  end
  if vim.fn.executable 'trash' == 0 then
    vim.api.nvim_echo({
      { 'trash not installed. Run: brew install trash\n', 'ErrorMsg' },
    }, false, {})
    return
  end

  -- Move cursor away so the prompt is visible
  local saved_pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  vim.ui.select({ 'yes', 'no' }, { prompt = 'Delete image file?' }, function(choice)
    vim.api.nvim_win_set_cursor(0, saved_pos)
    if choice ~= 'yes' then
      vim.api.nvim_echo({ { 'Cancelled.', 'Normal' } }, false, {})
      return
    end

    vim.fn.system { 'trash', vim.fn.fnameescape(abs) }

    if vim.fn.filereadable(abs) == 0 then
      vim.api.nvim_echo({ { 'Deleted: ' .. abs, 'Normal' } }, false, {})
      vim.cmd 'edit!'
      vim.cmd 'normal! dd'
    else
      -- Fallback: try rm
      local saved_pos2 = vim.api.nvim_win_get_cursor(0)
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.ui.select({ 'yes', 'no' }, { prompt = 'trash failed. Try rm?' }, function(rm_choice)
        vim.api.nvim_win_set_cursor(0, saved_pos2)
        if rm_choice == 'yes' then
          vim.fn.system { 'rm', vim.fn.fnameescape(abs) }
          if vim.fn.filereadable(abs) == 0 then
            vim.api.nvim_echo({ { 'Deleted with rm: ' .. abs, 'Normal' } }, false, {})
            vim.cmd 'edit!'
            vim.cmd 'normal! dd'
          else
            vim.api.nvim_echo({ { 'rm also failed: ' .. abs, 'ErrorMsg' } }, false, {})
          end
        end
      end)
    end
  end)
end, { desc = '[I]mage [d]elete file under cursor (macOS)' })

-- ---------------------------------------------------------------------------
-- <leader>iR  Rename image under cursor + update references in file
-- ---------------------------------------------------------------------------
vim.keymap.set('n', '<leader>iR', function()
  local image_path = get_image_path()
  if not image_path then
    vim.api.nvim_echo({ { 'No image found under cursor', 'WarningMsg' } }, false, {})
    return
  end
  if image_path:sub(1, 4) == 'http' then
    vim.api.nvim_echo({ { 'URL images cannot be renamed.', 'WarningMsg' } }, false, {})
    return
  end

  local current_dir = vim.fn.expand '%:p:h'
  local abs = current_dir .. '/' .. image_path
  if vim.fn.filereadable(abs) == 0 then
    vim.api.nvim_echo({ { 'File not found:\n' .. abs, 'ErrorMsg' } }, false, {})
    return
  end

  local dir = vim.fn.fnamemodify(abs, ':h')
  local ext = vim.fn.fnamemodify(abs, ':e')
  local current_name = vim.fn.fnamemodify(abs, ':t:r')

  vim.ui.input({ prompt = 'New name (no extension): ', default = current_name }, function(new_name)
    if not new_name or new_name == '' then
      vim.api.nvim_echo({ { 'Rename cancelled.', 'WarningMsg' } }, false, {})
      return
    end

    local new_abs = dir .. '/' .. new_name .. '.' .. ext
    if vim.fn.filereadable(new_abs) == 1 then
      vim.api.nvim_echo({ { 'File already exists: ' .. new_abs, 'ErrorMsg' } }, false, {})
      return
    end

    local ok, err = os.rename(abs, new_abs)
    if not ok then
      vim.api.nvim_echo({ { 'Rename failed: ' .. tostring(err), 'ErrorMsg' } }, false, {})
      return
    end

    local old_fname = vim.fn.fnamemodify(abs, ':t')
    local new_fname = vim.fn.fnamemodify(new_abs, ':t')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i = 0, #lines - 1 do
      local line = lines[i + 1]
      local img_start, img_end = line:find '!%[.-%]%(.-%)'
      if img_start and img_end then
        local md_part = line:match '!%[.-%]%(.-%)'
        local esc_old = old_fname:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]', '%%%1')
        local esc_new = new_fname:gsub('[%%]', '%%%%')
        local new_md = md_part:gsub(esc_old, esc_new)
        vim.api.nvim_buf_set_text(0, i, img_start - 1, i, img_start + #md_part - 1, { new_md })
      end
    end

    vim.cmd 'update'
    vim.api.nvim_echo({ { 'Renamed to: ' .. new_fname, 'Normal' } }, false, {})
  end)
end, { desc = '[I]mage [R]ename under cursor + update references' })

-- ---------------------------------------------------------------------------
-- <leader>if  Open image under cursor in Finder
-- ---------------------------------------------------------------------------
vim.keymap.set('n', '<leader>if', function()
  local image_path = get_image_path()
  if not image_path then
    print 'No image found under cursor'
    return
  end
  if image_path:sub(1, 4) == 'http' then
    print "URL image — use 'gx' to open in browser."
    return
  end
  local abs = vim.fn.expand '%:p:h' .. '/' .. image_path
  -- open -R reveals and selects the file in Finder
  local result = vim.fn.system('open -R ' .. vim.fn.shellescape(abs))
  if vim.v.shell_error == 0 then
    print('Opened in Finder: ' .. abs)
  else
    print('Failed to open in Finder: ' .. result)
  end
end, { desc = '[I]mage open in [f]inder (macOS)' })

-- ---------------------------------------------------------------------------
-- <leader>io  Open image under cursor in Preview
-- ---------------------------------------------------------------------------
vim.keymap.set('n', '<leader>io', function()
  local image_path = get_image_path()
  if not image_path then
    print 'No image found under cursor'
    return
  end
  if image_path:sub(1, 4) == 'http' then
    print "URL image — use 'gx' to open in browser."
    return
  end
  local abs = vim.fn.expand '%:p:h' .. '/' .. image_path
  local ok = os.execute('open -a Preview ' .. vim.fn.shellescape(abs))
  if ok then
    print('Opened in Preview: ' .. abs)
  else
    print('Failed to open in Preview: ' .. abs)
  end
end, { desc = '[I]mage [o]pen in Preview (macOS)' })

-- ---------------------------------------------------------------------------
-- which-key group label
-- ---------------------------------------------------------------------------
vim.defer_fn(function()
  local ok, wk = pcall(require, 'which-key')
  if ok then
    wk.add {
      { '<leader>i', group = '[I]mage utils' },
    }
  end
end, 100)

-- This file doesn't install a plugin — it's pure keymap/autocommand glue.
-- Return an empty table so lazy.nvim ignores it as a plugin spec.
return {}
