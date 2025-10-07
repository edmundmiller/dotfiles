-- sidekick.nvim: Your Neovim AI sidekick
-- Integrates AI CLIs (Claude, Gemini, etc.) with Next Edit Suggestions
-- Documentation: https://github.com/folke/sidekick.nvim

---@type LazySpec
return {
  "folke/sidekick.nvim",
  opts = {
    nes = { enabled = false }, -- Disable Next Edit Suggestions
    cli = {
      mux = {
        backend = "zellij",
        enabled = true,
      },
    },
  },
  -- stylua: ignore
  keys = {
    -- Quick toggle Claude (Ctrl+Space - common for AI assistants)
    {
      "<C-Space>",
      function() require("sidekick.cli").toggle({ name = "claude", focus = true }) end,
      mode = { "n", "t", "i" },
      desc = "Toggle Claude (quick)",
    },
    {
      "<leader>aa",
      function() require("sidekick.cli").toggle({ name = "claude", focus = true }) end,
      desc = "Sidekick Toggle Claude",
    },
    {
      "<leader>as",
      function() require("sidekick.cli").select({ filter = { installed = true } }) end,
      desc = "Select CLI (installed)",
    },
    {
      "<leader>aS",
      function() require("sidekick.cli").select() end,
      desc = "Select CLI (all available)",
    },
    {
      "<leader>at",
      function() require("sidekick.cli").send({ msg = "{this}" }) end,
      mode = { "x", "n" },
      desc = "Send This",
    },
    {
      "<leader>av",
      function() require("sidekick.cli").send({ msg = "{selection}" }) end,
      mode = { "x" },
      desc = "Send Visual Selection",
    },
    {
      "<leader>ap",
      function() require("sidekick.cli").prompt() end,
      mode = { "n", "x" },
      desc = "Sidekick Select Prompt",
    },
    {
      "<c-.>",
      function() require("sidekick.cli").focus() end,
      mode = { "n", "x", "i", "t" },
      desc = "Sidekick Switch Focus",
    },
  },
}
