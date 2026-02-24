-- FFF.nvim - Fast fuzzy file finder
-- https://github.com/dmtrKovalenko/fff.nvim
-- Rust-backed fuzzy file picker with git status, frecency, typo-resistant search

local repair_started = false

local function ensure_telescope()
  local ok, builtin = pcall(require, 'telescope.builtin')
  if ok then return builtin end
  vim.notify('FFF unavailable and telescope fallback not loaded', vim.log.levels.ERROR)
  return nil
end

local function fallback_find_files(opts)
  local telescope = ensure_telescope()
  if not telescope then return end
  telescope.find_files(opts or {})
end

local function fallback_find_in_git_root()
  local telescope = ensure_telescope()
  if not telescope then return end
  local ok = pcall(telescope.git_files, { show_untracked = true, recurse_submodules = true })
  if not ok then telescope.find_files() end
end

local function fallback_find_files_in_dir(dir)
  local telescope = ensure_telescope()
  if not telescope then return end
  local cwd = dir and dir ~= '' and vim.fn.expand(dir) or nil
  telescope.find_files({ cwd = cwd })
end

local function trigger_backend_repair_once()
  if repair_started then return end
  repair_started = true

  local ok, download = pcall(require, 'fff.download')
  if not ok then return end

  download.ensure_downloaded({}, function(success, err)
    vim.schedule(function()
      if success then
        vim.notify('fff.nvim backend installed. fff keymaps now use native backend.', vim.log.levels.INFO)
      else
        vim.notify('fff.nvim backend install failed: ' .. tostring(err), vim.log.levels.WARN)
      end
    end)
  end)
end

local function with_fff(method, fallback)
  return function(...)
    local ok, fff_or_err = pcall(function()
      require('fff.core').ensure_initialized()
      return require('fff')
    end)

    if ok then return fff_or_err[method](...) end

    trigger_backend_repair_once()
    vim.notify('fff backend unavailable, using telescope fallback', vim.log.levels.WARN)
    return fallback(...)
  end
end

return {
  'dmtrKovalenko/fff.nvim',
  -- fff plugin script will eagerly init if this is nil/false.
  -- Set before plugin load so startup never crashes on missing backend.
  init = function()
    vim.g.fff = vim.tbl_deep_extend('force', vim.g.fff or {}, { lazy_sync = true })
  end,
  config = function(_, opts)
    require('fff').setup(opts)

    -- Lazy.nvim build hooks are non-blocking here; ensure backend exists at runtime too.
    local ok, download = pcall(require, 'fff.download')
    if ok then
      local binary_path = download.get_binary_path()
      if not vim.uv.fs_stat(binary_path) then trigger_backend_repair_once() end
    end
  end,
  lazy = false,
  opts = {
    lazy_sync = true,
  },
  keys = {
    { '<Leader>ff', with_fff('find_files', fallback_find_files), desc = 'Find files (fff)' },
    { '<Leader>fF', with_fff('find_in_git_root', fallback_find_in_git_root), desc = 'Find files in git root' },
    {
      '<Leader>fd',
      function()
        local dir = vim.fn.input('Directory: ', '', 'dir')
        return with_fff('find_files_in_dir', fallback_find_files_in_dir)(dir)
      end,
      desc = 'Find in directory',
    },
    { '<Leader><Leader>', with_fff('find_in_git_root', fallback_find_in_git_root), desc = 'Find in git root' },
    { '<Leader>gf', with_fff('find_in_git_root', fallback_find_in_git_root), desc = 'Git files' },
  },
}
