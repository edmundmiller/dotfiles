-- cozy statuscolumn: DAP signs + line numbers + git signs without statuscol.nvim
local M = {}

local CUSTOM_STATUSCOLUMN = "%!v:lua.require'custom.statuscolumn'.render()"

local function starts_with_any(value, prefixes)
  for _, prefix in ipairs(prefixes) do
    if vim.startswith(value, prefix) then
      return true
    end
  end

  return false
end

local function get_line_sign_extmarks(bufnr, lnum)
  local ok, extmarks = pcall(
    vim.api.nvim_buf_get_extmarks,
    bufnr,
    -1,
    { lnum - 1, 0 },
    { lnum - 1, -1 },
    { type = 'sign', details = true }
  )

  if not ok then
    return {}
  end

  return extmarks
end

local function pick_sign(extmarks, prefixes)
  local best_sign = nil
  local best_priority = -math.huge

  for _, extmark in ipairs(extmarks) do
    local details = extmark[4] or {}
    local sign_name = details.sign_name or ''
    local sign_hl_group = details.sign_hl_group or ''

    if starts_with_any(sign_name, prefixes) or starts_with_any(sign_hl_group, prefixes) then
      local priority = tonumber(details.priority) or 0
      if best_sign == nil or priority > best_priority then
        best_sign = details
        best_priority = priority
      end
    end
  end

  if best_sign == nil then
    return nil
  end

  local sign_text = best_sign.sign_text or ''
  if sign_text == '' then
    return nil
  end

  return {
    text = vim.fn.strcharpart(sign_text, 0, 1),
    hl = best_sign.sign_hl_group,
  }
end

local function render_sign(sign)
  if sign == nil then
    return ' '
  end

  local text = sign.text:gsub('%%', '%%%%')
  if sign.hl ~= nil and sign.hl ~= '' then
    return '%#' .. sign.hl .. '#' .. text .. '%*'
  end

  return text
end

local function is_special_buffer(bufnr)
  return vim.bo[bufnr].buftype ~= ''
end

local function apply_to_window(winid, bufnr)
  if is_special_buffer(bufnr) then
    vim.wo[winid].statuscolumn = ''
    return
  end

  vim.wo[winid].statuscolumn = CUSTOM_STATUSCOLUMN
end

local function refresh_buffer_windows(bufnr)
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    apply_to_window(winid, bufnr)
  end
end

function M.render()
  local bufnr = vim.api.nvim_get_current_buf()
  local virtnum = vim.v.virtnum

  if virtnum < 0 then
    return ' ' .. ' ' .. '%=%l' .. ' ' .. ' '
  end

  local extmarks = get_line_sign_extmarks(bufnr, vim.v.lnum)

  local dap_sign = nil
  if virtnum == 0 then
    dap_sign = pick_sign(extmarks, { 'Dap' })
  end

  local git_sign = pick_sign(extmarks, { 'GitSigns' })

  return render_sign(dap_sign) .. ' ' .. '%=%l' .. ' ' .. render_sign(git_sign)
end

function M.setup()
  local group = vim.api.nvim_create_augroup('custom-statuscolumn', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'FileType', 'TermOpen' }, {
    group = group,
    callback = function(args)
      refresh_buffer_windows(args.buf)
    end,
  })

  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    apply_to_window(winid, bufnr)
  end
end

return M
