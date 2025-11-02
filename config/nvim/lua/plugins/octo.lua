-- Octo.nvim - GitHub integration with buffer-based UI
-- Extends the AstroCommunity octo-nvim pack with custom keybindings and enhancements
-- Complements gh.nvim: octo.nvim provides buffer-based interface (quick operations),
-- while gh.nvim provides panel-based UI (deep PR reviews)

---@type LazySpec
return {
  "pwntester/octo.nvim",
  -- Dependencies and lazy-loading are handled by the community pack
  opts = function(_, opts)
    -- Extend the community pack's default options
    return vim.tbl_deep_extend("force", opts or {}, {
      -- UI Configuration
      use_local_fs = false, -- use vim.ui.select instead of custom UI
      enable_builtin = false, -- use telescope for pickers
      default_remote = { "upstream", "origin" }, -- order to try remotes
      default_merge_method = "squash", -- "commit", "rebase", or "squash"
      ssh_aliases = {}, -- SSH aliases. e.g. `ssh_aliases = {["github.com-work"] = "github.com"}`

      -- Reaction picker - quick emoji reactions
      reaction_viewer_hint_icon = " ",
      user_icon = " ",
      timeline_marker = " ",
      timeline_indent = 2,

      -- Snippet configuration - templates for common operations
      snippet_context_lines = 4, -- number of lines around cursor to show in snippet

      -- GitHub CLI configuration
      gh_cmd = "gh", -- Command to use for GitHub CLI (ensure gh is installed)
      gh_env = {}, -- extra environment variables to pass to gh cli

      -- Issue/PR configuration
      issues = {
        order_by = {
          field = "CREATED_AT",
          direction = "DESC",
        },
      },

      pull_requests = {
        order_by = {
          field = "CREATED_AT",
          direction = "DESC",
        },
        always_select_remote_on_create = false,
      },

      -- File panel configuration
      file_panel = {
        size = 10, -- changed files panel rows
        use_icons = true, -- use web-devicons in file panel
      },

      -- Buffer-local mappings (active in review mode)
      mappings = {
        review_diff = {
          toggle_viewed = { lhs = "<localleader><space>", desc = "toggle viewer viewed state" },
        },
        file_panel = {
          toggle_viewed = { lhs = "<localleader><space>", desc = "toggle viewer viewed state" },
        },
      },

      -- Note: Other buffer-local mappings use community pack defaults
      -- Custom global keybindings are defined in the keys = {...} section below
    })
  end,

  keys = {
    -- === Minimal GitHub Keybindings (All under <Leader>gh) ===
    -- Complements gh.nvim panel operations with buffer-based quick actions
    -- Uses Telescope for discovery, Octo for actions

    { "<Leader>gh", group = "GitHub" },

    -- Discovery (via Telescope for better UX)
    { "<Leader>gho", "<cmd>Telescope octo prs<cr>", desc = "Browse PRs (Telescope)" },
    { "<Leader>ghi", "<cmd>Telescope octo issues<cr>", desc = "Browse issues (Telescope)" },

    -- Quick PR operations
    { "<Leader>ghp", "<cmd>Octo pr edit<cr>", desc = "Open current PR" },
    { "<Leader>ghm", "<cmd>Octo pr merge squash<cr>", desc = "Merge PR (squash)" },

    -- Review workflow
    { "<Leader>ghv", "<cmd>Octo review start<cr>", desc = "Start review" },
    { "<Leader>ghV", "<cmd>Octo review submit<cr>", desc = "Submit review" },

    -- Comments & suggestions
    { "<Leader>ghc", "<cmd>Octo comment add<cr>", desc = "Add comment" },
    { "<Leader>ghs", "<cmd>Octo suggestion add<cr>", desc = "Add suggestion" },
  },

  config = function(_, opts)
    require("octo").setup(opts)

    -- Enhanced Telescope integration
    local ok, telescope = pcall(require, "telescope")
    if ok then
      telescope.load_extension("octo")

      -- Add custom Telescope pickers for common workflows
      local builtin = require("telescope.builtin")
      local octo_telescope = require("telescope").extensions.octo

      -- Create custom Telescope commands
      vim.api.nvim_create_user_command("OctoSearchMyPRs", function()
        octo_telescope.search_prs({ filter = "author:@me" })
      end, { desc = "Search my PRs" })

      vim.api.nvim_create_user_command("OctoSearchMyIssues", function()
        octo_telescope.search_issues({ filter = "author:@me" })
      end, { desc = "Search my issues" })

      vim.api.nvim_create_user_command("OctoSearchAssignedToMe", function()
        octo_telescope.search_prs({ filter = "assignee:@me" })
      end, { desc = "Search PRs assigned to me" })

      vim.api.nvim_create_user_command("OctoSearchReviewRequests", function()
        octo_telescope.search_prs({ filter = "review-requested:@me" })
      end, { desc = "Search PRs requesting my review" })
    end

    -- Auto-commands for better workflow
    local octo_augroup = vim.api.nvim_create_augroup("OctoConfig", { clear = true })

    -- Auto-enable spell checking in octo buffers
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "octo",
      group = octo_augroup,
      callback = function()
        vim.opt_local.spell = true
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true
      end,
    })

    -- Highlight @mentions and #issues
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "octo",
      group = octo_augroup,
      callback = function()
        -- Add custom syntax highlighting
        vim.cmd([[
          syntax match OctoMention /@\w\+/
          syntax match OctoIssueRef /#\d\+/
          syntax match OctoCheckbox /\[[ x]\]/

          highlight link OctoMention Special
          highlight link OctoIssueRef Constant
          highlight link OctoCheckbox Todo
        ]])
      end,
    })

    -- Add custom commands for common workflows
    vim.api.nvim_create_user_command("OctoQuickReview", function()
      -- Quick approve workflow: start review -> approve -> submit
      vim.cmd("Octo review start")
      vim.defer_fn(function()
        vim.cmd("Octo review submit approve")
      end, 100)
    end, { desc = "Quick approve PR" })

    vim.api.nvim_create_user_command("OctoPRFromClipboard", function()
      -- Open PR from URL in clipboard
      local url = vim.fn.getreg("+")
      if url:match("github.com") then
        vim.cmd("Octo pr url " .. url)
      else
        vim.notify("No GitHub URL found in clipboard", vim.log.levels.WARN)
      end
    end, { desc = "Open PR from clipboard URL" })

    -- Template snippets for common review comments
    vim.api.nvim_create_user_command("OctoTemplateApprove", function()
      local template = [[
LGTM! ✅

Nice work on this PR. The changes look good to me.
      ]]
      vim.api.nvim_put(vim.split(template, "\n"), "l", true, true)
    end, { desc = "Insert approval template" })

    vim.api.nvim_create_user_command("OctoTemplateRequestChanges", function()
      local template = [[
Thanks for the PR! I have a few suggestions:

- [ ] TODO: Add specific feedback
- [ ] TODO: Add more feedback

Please let me know if you have any questions!
      ]]
      vim.api.nvim_put(vim.split(template, "\n"), "l", true, true)
    end, { desc = "Insert request changes template" })
  end,
}
