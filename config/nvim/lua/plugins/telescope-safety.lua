-- Defensive shim for Telescope highlight groups
-- Filters out any non-string highlight groups in display_highlights to avoid crashes
return {
  "nvim-telescope/telescope.nvim",
  optional = true,
  priority = 10,
  config = function(_, opts)
    local ok, highlights_mod = pcall(require, "telescope.pickers.highlights")
    if not ok then
      return
    end

    local original_new = highlights_mod.new
    if type(original_new) ~= "function" then
      return
    end

    highlights_mod.new = function(...)
      local highlighter = original_new(...)
      if type(highlighter) == "table" and type(highlighter.hi_display) == "function" then
        local original_hi_display = highlighter.hi_display
        highlighter.hi_display = function(self, row, prefix, display_highlights)
          if type(display_highlights) == "table" then
            local filtered = {}
            for _, block in ipairs(display_highlights) do
              if type(block) == "table" and type(block[2]) == "string" then
                table.insert(filtered, block)
              end
            end
            display_highlights = filtered
          end
          return original_hi_display(self, row, prefix, display_highlights)
        end
      end
      return highlighter
    end

    -- If telescope is already configured elsewhere, respect it
    if opts and next(opts) ~= nil then
      require("telescope").setup(opts)
    end
  end,
}
