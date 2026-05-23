local M = {}

M.vault_dir = vim.fn.expand '~/obsidian-vault'
M.projects_dir = M.vault_dir .. '/02_Projects'

M.project_aliases = (function()
  local ok, aliases = pcall(require, 'custom.private.obsidian-project-aliases')
  if ok and type(aliases) == 'table' then
    return aliases
  end
  return {}
end)()

function M.current_project_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  local start = bufname ~= '' and vim.fs.dirname(bufname) or vim.fn.getcwd()
  return vim.fs.root(start, { '.git', 'flake.nix', 'package.json', 'pyproject.toml', 'Cargo.toml', 'go.mod' })
    or vim.fn.getcwd()
end

function M.project_name_from_root(root)
  local name = vim.fs.basename(root)
  name = name:gsub('%-agent%-worktree%-%d+$', '')
  return name
end

local function yaml_scalar(value)
  value = vim.trim(value or '')
  value = value:gsub('^"(.*)"$', '%1'):gsub("^'(.*)'$", '%1')
  return value
end

function M.read_frontmatter_aliases(path)
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end

  local lines = vim.fn.readfile(path, '', 80)
  if lines[1] ~= '---' then
    return {}
  end

  local aliases = {}
  local in_aliases = false

  for i = 2, #lines do
    local line = lines[i]
    if line == '---' then
      break
    end

    local key, value = line:match('^([%w_-]+):%s*(.-)%s*$')
    if key ~= nil and not line:match('^%s') then
      -- Obsidian's native alias property is `aliases`. Keep legacy support for
      -- repoAliases/repo_aliases so existing notes do not break if any exist.
      in_aliases = key == 'aliases' or key == 'alias' or key == 'repoAliases' or key == 'repo_aliases'
      if in_aliases and value ~= '' then
        if value:match('^%[.*%]$') then
          for item in value:gsub('^%[', ''):gsub('%]$', ''):gmatch('[^,]+') do
            table.insert(aliases, yaml_scalar(item))
          end
        else
          table.insert(aliases, yaml_scalar(value))
        end
      end
    elseif in_aliases then
      local item = line:match('^%s*%-%s*(.-)%s*$')
      if item ~= nil and item ~= '' then
        table.insert(aliases, yaml_scalar(item))
      elseif not line:match('^%s*$') then
        in_aliases = false
      end
    end
  end

  return aliases
end

function M.project_from_frontmatter_alias(alias)
  local lower_alias = alias:lower()

  for name, type in vim.fs.dir(M.projects_dir) do
    if type == 'directory' then
      local readme = M.projects_dir .. '/' .. name .. '/README.md'
      for _, candidate in ipairs(M.read_frontmatter_aliases(readme)) do
        if candidate:lower() == lower_alias then
          return name
        end
      end
    end
  end

  return nil
end

function M.resolve_project_alias(project)
  return M.project_aliases[project]
    or M.project_aliases[project:lower()]
    or M.project_from_frontmatter_alias(project)
    or project
end

function M.project_note_path(project_override)
  local project = project_override ~= nil and project_override ~= '' and project_override
    or M.project_name_from_root(M.current_project_root())
  project = M.resolve_project_alias(project)
  local exact_dir = M.projects_dir .. '/' .. project

  if vim.fn.isdirectory(exact_dir) == 1 then
    return exact_dir .. '/README.md', project
  end

  local lower_project = project:lower()
  for name, type in vim.fs.dir(M.projects_dir) do
    if type == 'directory' and name:lower() == lower_project then
      return M.projects_dir .. '/' .. name .. '/README.md', name
    end
  end

  return exact_dir .. '/README.md', project
end

local function project_title(project)
  return (project:gsub('%-', ' '):gsub('(%f[%w]%w)', string.upper))
end

function M.ensure_project_note(path, project)
  if vim.fn.filereadable(path) == 1 then
    return
  end

  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  local date = os.date '%Y-%m-%d'
  local title = project_title(project)
  local lines = {
    '---',
    'type: project',
    'title: "' .. title .. '"',
    'dateCreated: ' .. date,
    'status: open',
    'now: false',
    'aliases:',
    '  - ' .. project,
    'tags:',
    '  - project',
    '---',
    '',
    '# ' .. title,
    '',
    '## Objective',
    '-',
    '',
    '## Key links',
    '- Repo: `' .. M.current_project_root() .. '`',
    '',
    '## Next actions',
    '- [ ] ',
    '',
    '## Notes',
    '-',
  }
  vim.fn.writefile(lines, path)
end

function M.open_current_project_note(opts)
  local project_override = opts and opts.args or nil
  local path, project = M.project_note_path(project_override)
  M.ensure_project_note(path, project)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.setup()
  vim.api.nvim_create_user_command('ObsidianProject', M.open_current_project_note, {
    desc = 'Open/create the Obsidian project note for the current repo',
    nargs = '?',
  })
end

return M
