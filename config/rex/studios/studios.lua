-- Seqera Studios for Rex: find running Studios, add them as Rex hosts, and
-- set Rex up on one so teammates can join the same sessions.
--
--   rex do studios.lua                            running Studios labelled "rex"
--   rex do studios.lua all=true                   every running SSH Studio you can see
--   rex do studios.lua cmd=add studio=NAME|ID     add a Studio to your Rex hosts
--   rex do studios.lua cmd=setup studio=NAME|ID   install Rex on a running Studio, then add it
--   rex do studios.lua cmd=claude studio=NAME|ID  install Claude Code there with team defaults and
--                                                 open it in a Rex tab (session=NAME, default "claude")
-- cmd=claude sends CLAUDE_CODE_OAUTH_TOKEN (from `claude setup-token`), or op read "$CLAUDE_TOKEN_OP",
-- to the Studio when one is set.
--
-- Options: ws=Org/workspace searches one workspace; as=LABEL names the Rex host;
-- stopped=true includes stopped Studios.
-- Token: TOWER_ACCESS_TOKEN, else op read "$SEQERA_TOKEN_OP" (an op:// reference).
-- API: TOWER_API_ENDPOINT, default https://api.cloud.seqera.io.

local args = rex.args or {}
local api = os.getenv("TOWER_API_ENDPOINT") or "https://api.cloud.seqera.io"
if not api:match("^https://") then error("TOWER_API_ENDPOINT must use https://", 0) end
local home = assert(os.getenv("HOME"), "HOME is not set")
local ssh_conf = os.getenv("SEQERA_REX_SSH_CONFIG") or (home .. "/.ssh/seqera-rex.conf")
local ssh_main = os.getenv("SEQERA_REX_SSH_MAIN") or (home .. "/.ssh/config")
local PAGE = 100
local MARK = "rex" -- a Studio label with this name means "shared over Rex"

local function sh(script, argv, opts)
  local cmd = { "sh", "-c", script, "sh" }
  for _, a in ipairs(argv or {}) do cmd[#cmd + 1] = a end
  return rex.exec(cmd, opts or {})
end

local function token()
  local t = os.getenv("TOWER_ACCESS_TOKEN") or os.getenv("SEQERA_ACCESS_TOKEN")
  if t and t ~= "" then return t end
  local ref = os.getenv("SEQERA_TOKEN_OP")
  if not ref or ref == "" then
    error("set TOWER_ACCESS_TOKEN, or SEQERA_TOKEN_OP to the op:// reference of your Seqera token", 0)
  end
  local r = rex.exec({ "op", "read", ref })
  if not r.ok then error("op read failed: " .. r.stderr, 0) end
  return (r.stdout:gsub("%s+$", ""))
end

-- GET each path in parallel. The token travels on stdin and through a shell
-- builtin, never in a process argument.
local FETCH = [[
IFS= read -r tok
d=$(mktemp -d) || exit 1
trap 'rm -rf "$d"' EXIT
i=0
for u in "$@"; do
  i=$((i + 1))
  ( printf 'Authorization: Bearer %s\n' "$tok" |
      curl -fsS --max-time 30 -H @- -H 'Accept: application/json' "$u" >"$d/$i" 2>"$d/$i.err" ||
      { printf 'error: '; cat "$d/$i.err"; } >"$d/$i" ) &
done
wait
i=0
for u in "$@"; do i=$((i + 1)); cat "$d/$i"; printf '\036'; done
]]

local function get_all(tok, paths)
  local urls = {}
  for i, p in ipairs(paths) do urls[i] = api .. p end
  local r = sh(FETCH, urls, { stdin = tok .. "\n" })
  if not r.ok then error("fetch failed: " .. r.stderr, 0) end
  local out, i = {}, 0
  for chunk in r.stdout:gmatch("([^\030]*)\030") do
    i = i + 1
    local ok, v = pcall(rex.json.decode, chunk)
    out[i] = (ok and type(v) == "table") and v or { error = chunk:sub(1, 200) }
  end
  return out
end

local function get(tok, path)
  local v = get_all(tok, { path })[1]
  if v == nil or v.error then error(path .. ": " .. tostring(v and v.error), 0) end
  return v
end

local function slug(s)
  return (s:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

-- Every SSH-enabled Studio you can see; running ones only unless stopped is true.
local function studios(tok, stopped)
  local me = get(tok, "/user-info").user
  local ws = get(tok, string.format("/user/%.0f/workspaces", me.id))
  local paths, names = {}, {}
  for _, w in ipairs(ws.orgsAndWorkspaces or {}) do
    local name = w.workspaceId and (w.orgName .. "/" .. w.workspaceName)
    if name and (not args.ws or args.ws == name) then
      paths[#paths + 1] = string.format("/studios?workspaceId=%.0f&max=%d&attributes=labels%s",
        w.workspaceId, PAGE, stopped and "" or "&search=status%3Arunning")
      names[#paths] = name
    end
  end
  if #paths == 0 then error("no workspace matches ws=" .. tostring(args.ws), 0) end
  local rows, skipped = {}, 0
  local function collect(i, page)
    for _, s in ipairs(page.studios) do
      local d = s.sshDetails
      if type(d) == "table" and type(s.configuration) == "table" and s.configuration.sshEnabled == true then
        local shared = false
        for _, l in ipairs(type(s.labels) == "table" and s.labels or {}) do
          if l.name == MARK then shared = true end
        end
        rows[#rows + 1] = {
          id = s.sessionId, name = s.name, workspace = names[i],
          owner = type(s.user) == "table" and s.user.userName or "?",
          status = type(s.statusInfo) == "table" and s.statusInfo.status or "?", shared = shared,
          alias = "seqera-studio-a" .. s.sessionId, host = d.host, port = d.port, user = d.user,
        }
      end
    end
  end
  -- Fetch page N of every workspace together; keep paging the ones that filled a page.
  local offset, todo = 0, {}
  for i = 1, #paths do todo[i] = i end
  while #todo > 0 do
    local batch = {}
    for k, i in ipairs(todo) do batch[k] = paths[i] .. "&offset=" .. offset end
    local next_todo = {}
    for k, page in ipairs(get_all(tok, batch)) do
      local i = todo[k]
      if type(page.studios) ~= "table" then
        skipped = skipped + 1
      else
        collect(i, page)
        if #page.studios == PAGE then next_todo[#next_todo + 1] = i end
      end
    end
    todo, offset = next_todo, offset + PAGE
  end
  table.sort(rows, function(a, b)
    if a.workspace ~= b.workspace then return a.workspace < b.workspace end
    return a.name < b.name
  end)
  return rows, skipped
end

local function find(rows, want)
  if not want or want == "" then error("pass studio=NAME or studio=SESSION_ID", 0) end
  want = tostring(want)
  local hits = {}
  for _, s in ipairs(rows) do
    if s.id == want or s.name == want or s.alias == want then hits[#hits + 1] = s end
  end
  if #hits == 0 then error("no SSH-enabled Studio you can see matches " .. want .. " (ws=Org/workspace narrows the search)", 0) end
  if #hits > 1 then error(want .. " matches " .. #hits .. " Studios; use the session ID", 0) end
  return hits[1]
end

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- Replace path atomically with a 0600 file. A symlink (such as a Nix-managed
-- ~/.ssh/config) is left alone, because renaming over it would unlink it.
local WRITE = [[
set -eu
if [ -L "$1" ]; then echo "$1 is a symlink; add this line to its source instead: $2" >&2; exit 1; fi
umask 077
tmp=$(mktemp "$1.XXXXXX")
cat >"$tmp" && mv -f "$tmp" "$1" || { rm -f "$tmp"; exit 1; }
]]

local function write(path, s, hint)
  local r = sh(WRITE, { path, hint or "" }, { stdin = s })
  if not r.ok then error("cannot write " .. path .. ": " .. r.stderr, 0) end
end

-- Rex's ssh:// endpoints refuse % escapes, and Studio logins contain "@",
-- so each Studio gets a Host alias in its own file.
local function ensure_alias(s)
  if not rex.exec({ "mkdir", "-p", home .. "/.ssh" }).ok then error("cannot create ~/.ssh", 0) end
  local cur = read(ssh_conf) or "# Written by Rex studios.lua; one Host per Seqera Studio.\n"
  if not cur:find("\nHost " .. s.alias .. "\n", 1, true) then
    write(ssh_conf, cur .. string.format(
      "\n# %s (%s, owner %s)\nHost %s\n    HostName %s\n    Port %.0f\n    User %s\n    ServerAliveInterval 30\n    ServerAliveCountMax 3\n",
      s.name, s.workspace, s.owner, s.alias, s.host, s.port, s.user))
  end
  local include = 'Include "' .. ssh_conf .. '"'
  local main = read(ssh_main) or ""
  if not main:find(include, 1, true) then
    -- Include must come before the first Host block to apply everywhere.
    write(ssh_main, include .. "\n\n" .. main, include)
  end
end

local function run(argv)
  local r = rex.exec(argv)
  return r.ok, ((r.stdout .. r.stderr):gsub("%s+$", ""))
end

local function host_label(s) return args.as or slug(s.name) end

-- The Mac app keeps its own host list; rex hosts does not reach it yet.
local function app_hint(s)
  return "In the Rex app: Add Remote Host… and enter ssh://" .. s.alias
end

local function add(s)
  ensure_alias(s)
  local label = host_label(s)
  local ok, out = run({ "rex", "hosts", "add", label, "ssh://" .. s.alias, "--icon", "globe" })
  -- Re-adding is fine only when the existing host points at this Studio.
  if not ok and not out:find("already exists (ssh://" .. s.alias .. ")", 1, true) then
    error(out .. "\nPick another host name with as=LABEL.", 0)
  end
  return label
end

-- Studio images often lack XDG_RUNTIME_DIR, where Rex keeps its socket.
local PREPARE = [[
set -eu
dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
mkdir -p "$dir"
chmod 700 "$dir"
if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -w /etc/environment ] && ! grep -q '^XDG_RUNTIME_DIR=' /etc/environment; then
  printf '\nXDG_RUNTIME_DIR=%s\n' "$dir" >>/etc/environment
fi
echo "user=$(id -un) uid=$(id -u) runtime=$dir"
]]

-- The Connect proxy intermittently drops a fresh ssh with exit 255.
local function retry(argv, opts)
  local r
  for _ = 1, 3 do
    r = rex.exec(argv, opts or {})
    if r.ok or r.code ~= 255 then break end
  end
  return r
end

-- Portable Claude Code defaults for a shared Studio. Keep machine-specific
-- hooks, statuslines and local plugin paths out of here.
local CLAUDE_SETTINGS = [==[
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "alwaysThinkingEnabled": true,
  "idleCompaction": true,
  "permissions": {
    "defaultMode": "auto",
    "allow": [
      "Read(**)", "Edit(**)", "WebSearch", "TodoWrite(**)", "Task(**)",
      "Bash(ls:*)", "Bash(cat:*)", "Bash(head:*)", "Bash(tail:*)", "Bash(rg:*)", "Bash(grep:*)",
      "Bash(find:*)", "Bash(wc:*)", "Bash(diff:*)", "Bash(jq:*)", "Bash(git status:*)",
      "Bash(git diff:*)", "Bash(git log:*)", "Bash(nextflow:*)", "Bash(nf-test:*)", "Bash(tw:*)",
      "Bash(python3:*)", "Bash(pytest:*)", "Bash(make:*)"
    ],
    "deny": [
      "Bash(git commit --no-verify:*)", "Bash(git commit * --no-verify*)",
      "Bash(*--no-gpg-sign*)", "Bash(git push --force:*)", "Bash(git push * --force*)"
    ]
  }
}
]==]

-- Installs Claude Code if missing, writes settings (keeping a .bak of a
-- different existing file), skips the first-run screens, and stores the token.
-- stdin: one token line (may be empty), then the settings JSON.
local CLAUDE_PREPARE = [[
set -eu
IFS= read -r tok || tok=
mkdir -p ~/.claude
chmod 700 ~/.claude
cat >~/.claude/settings.json.new
if [ -e ~/.claude/settings.json ] && ! cmp -s ~/.claude/settings.json ~/.claude/settings.json.new; then
  cp ~/.claude/settings.json ~/.claude/settings.json.bak
fi
mv ~/.claude/settings.json.new ~/.claude/settings.json
if [ -n "$tok" ]; then
  (umask 077 && printf '%s\n' "$tok" >~/.claude/.oauth-token)
fi
# The installer puts claude in ~/.local/bin, which Studio shells leave off PATH.
for rc in ~/.bashrc ~/.profile; do
  grep -q 'HOME/.local/bin' "$rc" 2>/dev/null || printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$rc"
done
grep -q 'claude/.oauth-token' ~/.bashrc 2>/dev/null ||
  printf '\n[ -r ~/.claude/.oauth-token ] && export CLAUDE_CODE_OAUTH_TOKEN="$(cat ~/.claude/.oauth-token)"\n' >>~/.bashrc
[ -x ~/.local/bin/claude ] || curl -fsSL https://claude.ai/install.sh | bash >/dev/null
# Perl ships with every Debian/Ubuntu image; python3 often does not.
if perl -MJSON::PP -e 1 2>/dev/null; then
  perl -MJSON::PP -e '
    my $p = "$ENV{HOME}/.claude.json";
    my $c = {};
    if (open my $f, "<", $p) { local $/; $c = decode_json(<$f>); }
    $c->{hasCompletedOnboarding} = JSON::PP::true;
    $c->{theme} ||= "auto";
    $c->{projects}{$ENV{HOME}}{hasTrustDialogAccepted} = JSON::PP::true;
    open my $o, ">", "$p.new" or die $!; print $o JSON::PP->new->pretty->encode($c); close $o;
    rename "$p.new", $p or die $!;'
elif [ ! -e ~/.claude.json ]; then
  printf '{"hasCompletedOnboarding": true, "theme": "auto"}\n' >~/.claude.json
fi
printf 'claude %s, token %s\n' "$(~/.local/bin/claude --version | cut -d' ' -f1)" \
  "$([ -s ~/.claude/.oauth-token ] && echo stored || echo 'not set: log in with /login')"
]]

local function claude_token()
  local t = os.getenv("CLAUDE_CODE_OAUTH_TOKEN")
  if t and t ~= "" then return t end
  local ref = os.getenv("CLAUDE_TOKEN_OP")
  if not ref or ref == "" then return "" end
  local r = rex.exec({ "op", "read", ref })
  if not r.ok then error("op read failed: " .. r.stderr, 0) end
  return (r.stdout:gsub("%s+$", ""))
end

local cmd = args.cmd or "list"
local tok = token()

if cmd == "list" then
  local rows, skipped = studios(tok, args.stopped == true)
  local fmt = "%-4s %-9s %-9s %-28s %-18s %s"
  local lines = {}
  for _, s in ipairs(rows) do
    if args.all == true or s.shared then
      lines[#lines + 1] = string.format(fmt, s.shared and MARK or "-", s.id, s.status, s.workspace, s.owner, s.name)
    end
  end
  if #lines == 0 then
    lines[1] = args.all == true and "No SSH-enabled Studios found."
      or ("No running Studio has a '" .. MARK .. "' label. all=true lists every running SSH Studio.")
  else
    table.insert(lines, 1, string.format(fmt, "REX", "SESSION", "STATUS", "WORKSPACE", "OWNER", "NAME"))
  end
  if skipped > 0 then lines[#lines + 1] = skipped .. " workspace(s) could not be searched." end
  print(table.concat(lines, "\n"))
elseif cmd == "add" then
  local s = find(studios(tok, true), args.studio)
  local label = add(s)
  print(string.format("Added %s as CLI host '%s': rex -S %s ls\n%s", s.name, label, label, app_hint(s)))
elseif cmd == "setup" then
  local s = find(studios(tok, false), args.studio)
  ensure_alias(s)
  -- accept-new trusts the Connect proxy's key on first contact and still rejects a changed key.
  local r = retry({ "ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", s.alias, PREPARE })
  if not r.ok then error("preparing " .. s.alias .. " failed: " .. r.stdout .. r.stderr, 0) end
  local who = (r.stdout:gsub("%s+$", ""))
  local label = host_label(s)
  r = retry({ "rex", "server", "install", "ssh://" .. s.alias, "--label", label, "--yes" })
  if not r.ok then error("rex server install failed:\n" .. r.stdout .. r.stderr, 0) end
  print(table.concat({
    string.format("Rex is running on %s (%s) as CLI host '%s'.", s.name, who, label),
    app_hint(s),
    s.shared and "Teammates see it in: rex do studios.lua"
      or ("Add a '" .. MARK .. "' label to the Studio so teammates find it with: rex do studios.lua"),
    "Teammates join with: rex do studios.lua cmd=add studio=" .. s.id,
  }, "\n"))
elseif cmd == "claude" then
  local s = find(studios(tok, false), args.studio)
  ensure_alias(s)
  local label = host_label(s)
  local r = retry({ "ssh", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new", s.alias, CLAUDE_PREPARE },
    { stdin = claude_token() .. "\n" .. CLAUDE_SETTINGS })
  if not r.ok then error("installing Claude Code on " .. s.alias .. " failed: " .. r.stdout .. r.stderr, 0) end
  local session = args.session or "claude"
  -- Session labels are not unique, so create one only when none has this label.
  local ls = rex.exec({ "rex", "-S", label, "ls", "--json" })
  if not ls.ok then error("cannot reach Rex on '" .. label .. "': " .. ls.stderr .. "\nRun setup first.", 0) end
  local exists = false
  for _, x in ipairs(rex.json.decode(ls.stdout).sessions or {}) do
    if x.label == session then exists = true end
  end
  if not exists then rex.exec({ "rex", "-S", label, "new", session }) end
  local w = rex.exec({ "rex", "-S", label, "window", "new", "-s", session, "claude", "--", "bash", "-lc",
    '[ -r ~/.claude/.oauth-token ] && export CLAUDE_CODE_OAUTH_TOKEN="$(cat ~/.claude/.oauth-token)"; cd ~ && exec ~/.local/bin/claude' })
  if not w.ok then error("opening the Claude tab failed: " .. w.stderr .. "\nRun setup first.", 0) end
  print((r.stdout:gsub("%s+$", "")) .. "\nClaude is open in session '" .. session .. "' on host '" .. label .. "'.")
else
  error("unknown cmd=" .. cmd .. "; use list, add, setup, or claude", 0)
end
