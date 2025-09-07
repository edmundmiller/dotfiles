-- Snacks.nvim image viewer configuration
-- Provides inline image rendering and image viewing capabilities
return {
  "folke/snacks.nvim",
  opts = {
    -- Image viewer configuration
    image = {
      enabled = true,
      -- Backend to use for rendering images
      -- "kitty" uses the Kitty graphics protocol (works with Ghostty)
      backend = "kitty",
      
      -- Maximum width/height for images
      max_width = 120,
      max_height = 40,
      
      -- Image formats to support
      formats = {
        "png",
        "jpg",
        "jpeg",
        "gif",
        "webp",
        "pdf",
        "mp4",
        "svg",
      },
      
      -- Document inline rendering settings
      doc = {
        enabled = true,
        -- Show images inline in documents
        inline = true,
        -- Update images when scrolling
        update_on_scroll = true,
        -- Languages to enable inline rendering for
        langs = {
          "markdown",
          "html",
          "norg",
          "tsx",
          "javascript",
          "css",
          "vue",
          "svelte",
          "latex",
          "typst",
        },
      },
      
      -- Window settings for image viewer
      window = {
        border = "rounded",
        backdrop = 60,
        width = 0.8,
        height = 0.8,
      },
    },
  },
  keys = {
    -- Image viewer keybindings
    { "<leader>ii", function() require("snacks").image.view() end, desc = "View image under cursor" },
    { "<leader>id", function() require("snacks").image.toggle_doc() end, desc = "Toggle inline images" },
    { "<leader>iz", function() require("snacks").image.zoom_in() end, desc = "Zoom in image" },
    { "<leader>iZ", function() require("snacks").image.zoom_out() end, desc = "Zoom out image" },
    { "<leader>ir", function() require("snacks").image.reset() end, desc = "Reset image zoom" },
    
    -- Navigation in image viewer
    { "]i", function() require("snacks").image.next() end, desc = "Next image" },
    { "[i", function() require("snacks").image.prev() end, desc = "Previous image" },
  },
}