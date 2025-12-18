-- Enhancements for opencode.nvim (base config from astrocommunity.ai.opencode-nvim)
-- Adds: operator mode, quick prompts, terminal configuration, and additional keybindings

---@type LazySpec
return {
  -- Extend the astrocommunity opencode.nvim config
  {
    "NickvanDyke/opencode.nvim",
    opts = {
      -- Match claudecode.nvim terminal style
      provider = {
        enabled = "snacks",
        snacks = {
          win = {
            position = "right",
            width = 0.3,
          },
        },
      },

      -- Enable autoread for real-time file reloads
      events = {
        reload = true,
      },
    },

    keys = {
      -- Operator mode for text objects (e.g., govip to add paragraph)
      {
        "go",
        function() return require("opencode").operator("@this ") end,
        mode = { "n", "x" },
        expr = true,
        desc = "Add range to opencode",
      },
      {
        "goo",
        function() return require("opencode").operator("@this ") .. "_" end,
        mode = "n",
        expr = true,
        desc = "Add line to opencode",
      },

      -- Quick prompt shortcuts (complement AstroCommunity's <Leader>O* bindings)
      {
        "<Leader>Or",
        function() require("opencode").prompt("review", { submit = true }) end,
        mode = { "n", "x" },
        desc = "Review code",
      },
      {
        "<Leader>Of",
        function() require("opencode").prompt("fix", { submit = true }) end,
        mode = "n",
        desc = "Fix diagnostics",
      },
      {
        "<Leader>Oo",
        function() require("opencode").prompt("optimize", { submit = true }) end,
        mode = { "n", "x" },
        desc = "Optimize code",
      },
      {
        "<Leader>OT",
        function() require("opencode").prompt("test", { submit = true }) end,
        mode = { "n", "x" },
        desc = "Add tests",
      },
      {
        "<Leader>Od",
        function() require("opencode").prompt("document", { submit = true }) end,
        mode = { "n", "x" },
        desc = "Document code",
      },
      {
        "<Leader>Oi",
        function() require("opencode").prompt("implement", { submit = true }) end,
        mode = { "n", "x" },
        desc = "Implement code",
      },

      -- Quick toggle (global, matches claudecode's <M-c> pattern)
      {
        "<M-o>",
        function() require("opencode").toggle() end,
        mode = { "n", "t" },
        desc = "Quick toggle OpenCode",
      },

      -- Interrupt current session
      {
        "<Leader>Oc",
        function() require("opencode").command("session.interrupt") end,
        mode = "n",
        desc = "Interrupt session",
      },

      -- Compact session (reduce context)
      {
        "<Leader>OC",
        function() require("opencode").command("session.compact") end,
        mode = "n",
        desc = "Compact session",
      },
    },
  },

  -- Add which-key descriptions for the new prompt shortcuts
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      -- Ensure autoread is enabled for real-time file reloads
      opts.options = opts.options or {}
      opts.options.opt = opts.options.opt or {}
      opts.options.opt.autoread = true
    end,
  },
}
