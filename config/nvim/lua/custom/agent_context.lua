local M = {}

local function context_location(absolute, visual)
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' or vim.bo.buftype ~= '' then
    vim.notify('Agent context: open a file before copying a reference', vim.log.levels.WARN)
    return
  end
  if not absolute then
    local root = vim.fs.root(0, '.git') or vim.fn.getcwd()
    path = vim.fs.relpath(root, path) or path
  end
  local first = visual and vim.fn.line "'<" or vim.fn.line '.'
  local last = visual and vim.fn.line "'>" or first
  return path, first, last
end

-- Copy an agent reference relative to the repository root, or cwd outside Git.
function M.copy_reference(absolute, visual)
  local path, first, last = context_location(absolute, visual)
  if not path then return end
  local reference = path .. ':' .. first .. (last ~= first and ('-' .. last) or '')
  vim.fn.setreg('+', reference)
  vim.notify('Copied ' .. reference)
end

-- Copy whole selected lines so the agent's snippet matches its line metadata.
function M.copy_codeblock()
  local path, first, last = context_location(false, true)
  if not path then return end
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local text = table.concat(lines, '\n')
  local fence_length = 3
  for backticks in text:gmatch '`+' do
    fence_length = math.max(fence_length, #backticks + 1)
  end
  local fence = string.rep('`', fence_length)
  local languages = { typescript = 'ts', typescriptreact = 'tsx', javascript = 'js', javascriptreact = 'jsx' }
  local language = languages[vim.bo.filetype] or vim.bo.filetype
  local header = string.format('%s%s filename=%q line=%d', fence, language, path, first)
  vim.fn.setreg('+', header .. '\n' .. text .. '\n' .. fence)
  vim.notify('Copied code from ' .. path .. ':' .. first .. '-' .. last)
end

return M
