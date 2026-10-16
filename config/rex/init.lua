-- https://www.superlogical.com/rex/docs/customize/config
-- Match tmux/Herdr's prefix without launching either multiplexer inside Rex.
-- Reload on the server host with: rex config reload

-- Ctrl+C starts a sequence; press it twice to interrupt the foreground program.
rex.bind("ctrl+c>ctrl+c", "pane.send_key", { key = "ctrl+c" })

rex.bind("ctrl+c>c", "client.tab.new")
rex.bind("ctrl+c>n", "client.tab.next")
rex.bind("ctrl+c>p", "client.tab.previous")
rex.bind("ctrl+c>s", "pane.split", { direction = "down" })
rex.bind("ctrl+c>v", "pane.split", { direction = "right" })
rex.bind("ctrl+c>x", "client.close")
rex.bind("ctrl+c>z", "pane.zoom")
rex.bind("ctrl+c>w", "session.switch")
rex.bind("ctrl+c>b", "client.sidebar.toggle")

-- Use the documented server API for directional focus. Client action names
-- vary by client; block_id must be explicit even though session_id is inferred.
local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
  -- Bare Ctrl+H/J/K/L are unbound by default and pass through to applications.
  rex.bind("ctrl+c>" .. key, function(ctx)
    local _, err = rex.session.focus_direction({
      block_id = ctx.block_id,
      direction = direction,
    })
    if err ~= nil then
      error(err, 0)
    end
    return true
  end)

  -- Match Ghostty's direct resize shortcuts.
  rex.bind("ctrl+shift+" .. key, "pane.resize", { direction = direction, amount = 10 })
  rex.bind("resize/" .. key, "pane.resize", { direction = direction })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = direction, amount = 15 })
end

-- An exclusive mode prevents resize keystrokes from reaching the shell.
rex.mode("resize", { exclusive = true })
rex.bind("ctrl+c>r", "client.mode.enter", { name = "resize" })
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")
rex.bind("resize/escape", "client.mode.exit")
