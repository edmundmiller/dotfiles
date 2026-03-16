-- cozy statuscolumn: DAP signs + line numbers + gitsigns without statuscol.nvim
local api = vim.api

local M = {}

local DAP_COLUMN_WIDTH = 2
local NUMBER_RIGHT_PAD = 1
local GIT_COLUMN_WIDTH = 2

local CUSTOM_STATUSCOLUMN = "%{%v:lua.require('custom.statuscolumn').render()%}"

local DISABLED_BUFTYPES = {
  help = true,
  nofile = true,
  prompt = true,
  terminal = true,
}

local DISABLED_FILETYPES = {
  ['lazy'] = true,
  ['mason'] = true,
  ['neo-tree'] = true,
}

---@type table<integer, string>
local ns_cache = {}

---@param ns_id integer
---@return string
local function ns_name(ns_id)
  if ns_cache[ns_id] then
    return ns_cache[ns_id]
  end

  for name, id in pairs(api.nvim_get_namespaces()) do
    ns_cache[id] = name
  end

  return ns_cache[ns_id] or ''
end

---@param lnum integer
---@return vim.api.keyset.extmark_details?, vim.api.keyset.extmark_details?
local function get_signs(lnum)
  local marks = api.nvim_buf_get_extmarks(0, -1, { lnum - 1, 0 }, { lnum - 1, -1 }, { details = true, type = 'sign' })

  ---@type vim.api.keyset.extmark_details?
  local dap_sign
  ---@type vim.api.keyset.extmark_details?
  local git_sign

  for _, mark in ipairs(marks) do
    local details = mark[4]
    if details and details.sign_text then
      local priority = tonumber(details.priority) or 0

      if details.sign_name and details.sign_name:match '^Dap' then
        if not dap_sign or priority > (tonumber(dap_sign.priority) or 0) then
          dap_sign = details
        end
      elseif details.ns_id and ns_name(details.ns_id):find 'gitsigns' then
        if not git_sign or priority > (tonumber(git_sign.priority) or 0) then
          git_sign = details
        end
      end
    end
  end

  return dap_sign, git_sign
end

---@param text string
---@param width integer
---@return string
local function fit_width(text, width)
  local current = vim.fn.strdisplaywidth(text)
  if current > width then
    local trimmed = vim.fn.strcharpart(text, 0, 1)
    current = vim.fn.strdisplaywidth(trimmed)
    text = trimmed
  end

  if current < width then
    text = text .. string.rep(' ', width - current)
  end

  return text
end

---@param text string
---@param hl string?
---@return string
local function with_hl(text, hl)
  local escaped = text:gsub('%%', '%%%%')
  if hl and hl ~= '' then
    return '%#' .. hl .. '#' .. escaped .. '%*'
  end

  return escaped
end

---@param sign vim.api.keyset.extmark_details?
---@return string
local function render_dap(sign)
  if not sign or not sign.sign_text then
    return string.rep(' ', DAP_COLUMN_WIDTH)
  end

  local text = fit_width(sign.sign_text, DAP_COLUMN_WIDTH)
  local hl = sign.sign_hl_group ~= '' and sign.sign_hl_group or sign.sign_name
  return with_hl(text, hl)
end

---@param sign vim.api.keyset.extmark_details?
---@return string
local function render_git(sign)
  if not sign or not sign.sign_text then
    return string.rep(' ', GIT_COLUMN_WIDTH)
  end

  local text = fit_width(sign.sign_text, GIT_COLUMN_WIDTH)
  return with_hl(text, sign.sign_hl_group)
end

---@return string
local function number_column()
  if vim.v.virtnum ~= 0 then
    return '%='
  end

  local lnum = vim.v.relnum > 0 and vim.v.relnum or vim.v.lnum
  local lnum_str = tostring(lnum)
  local left_pad = string.rep(' ', math.max(vim.wo.numberwidth - #lnum_str, 0))

  return '%=' .. left_pad .. lnum_str .. string.rep(' ', NUMBER_RIGHT_PAD)
end

---@param bufnr integer
---@return boolean
local function is_disabled_buffer(bufnr)
  if DISABLED_BUFTYPES[vim.bo[bufnr].buftype] then
    return true
  end

  return DISABLED_FILETYPES[vim.bo[bufnr].filetype] == true
end

---@param winid integer
---@param bufnr integer
local function apply_to_window(winid, bufnr)
  if is_disabled_buffer(bufnr) then
    vim.wo[winid].statuscolumn = ''
    return
  end

  vim.wo[winid].statuscolumn = CUSTOM_STATUSCOLUMN
end

---@param bufnr integer
local function refresh_buffer_windows(bufnr)
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    apply_to_window(winid, bufnr)
  end
end

---@return string
function M.render()
  if vim.bo[0].buftype == 'quickfix' then
    return number_column()
  end

  local dap_sign, git_sign = get_signs(vim.v.lnum)
  local left = vim.v.virtnum == 0 and render_dap(dap_sign) or string.rep(' ', DAP_COLUMN_WIDTH)

  return left .. number_column() .. render_git(git_sign)
end

function M.setup()
  local group = api.nvim_create_augroup('custom-statuscolumn', { clear = true })

  api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'FileType', 'TermOpen' }, {
    group = group,
    callback = function(args)
      refresh_buffer_windows(args.buf)
    end,
  })

  api.nvim_create_autocmd('OptionSet', {
    group = group,
    pattern = 'buftype',
    callback = function()
      refresh_buffer_windows(api.nvim_get_current_buf())
    end,
  })

  for _, winid in ipairs(api.nvim_list_wins()) do
    local bufnr = api.nvim_win_get_buf(winid)
    apply_to_window(winid, bufnr)
  end
end

return M
