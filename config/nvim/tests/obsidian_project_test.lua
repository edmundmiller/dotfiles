local repo, vault, case = arg[1], arg[2], arg[3]
package.path = repo .. '/config/nvim/lua/?.lua;' .. repo .. '/config/nvim/lua/?/init.lua;' .. package.path

local function read_lines(path)
  local lines = {}
  for line in io.lines(path) do
    table.insert(lines, line)
  end
  return lines
end

vim = {
  trim = function(s)
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
  end,
  fn = {
    expand = function(path)
      return path == '~/obsidian-vault' and vault or path
    end,
    filereadable = function(path)
      local f = io.open(path)
      if f then
        f:close()
        return 1
      end
      return 0
    end,
    readfile = function(path)
      return read_lines(path)
    end,
    isdirectory = function(path)
      local ok = os.execute('[ -d ' .. string.format('%q', path) .. ' ] >/dev/null 2>&1')
      return ok == true and 1 or 0
    end,
    getcwd = function()
      return repo
    end,
  },
  api = {
    nvim_buf_get_name = function()
      return ''
    end,
  },
  fs = {
    basename = function(path)
      return path:match('([^/]+)$')
    end,
    dirname = function(path)
      return path:match('^(.*)/[^/]*$') or '.'
    end,
    root = function()
      return repo
    end,
    dir = function(path)
      local p = io.popen('find ' .. string.format('%q', path) .. ' -mindepth 1 -maxdepth 1 -type d -exec basename {} \\; | sort')
      return function()
        local name = p:read('*l')
        if not name then
          p:close()
          return nil
        end
        return name, 'directory'
      end
    end,
  },
}

local project = require 'custom.obsidian_project'

if case == 'read_aliases' then
  local aliases = project.read_frontmatter_aliases(vault .. '/02_Projects/Gradient/README.md')
  assert(aliases[1] == 'stimulus', aliases[1])
  assert(aliases[2] == 'stimulus-api', aliases[2])
elseif case == 'resolve_aliases' then
  assert(project.resolve_project_alias('stimulus') == 'Gradient')
  assert(project.resolve_project_alias('STIMULUS-API') == 'Gradient')
  local path, name = project.project_note_path('dotfiles-agent')
  assert(name == 'Dotfiles', name)
  assert(path == vault .. '/02_Projects/Dotfiles/README.md', path)
elseif case == 'worktree_suffix' then
  assert(project.project_name_from_root('/tmp/dotfiles-agent-worktree-0007') == 'dotfiles')
else
  error('unknown case: ' .. tostring(case))
end
