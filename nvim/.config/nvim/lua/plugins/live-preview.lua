-- Browser preview with KaTeX math, Mermaid diagrams and scroll sync — for what
-- a terminal can't render. Pure Lua, no Node/Python. <leader>mb / <leader>mB.
return {
  "brianhuster/live-preview.nvim",
  version = "*",
  cmd = "LivePreview",
  config = function()
    require("livepreview.config").set({
      port = 5500,
      browser = "default",
      -- Serve from the file's directory so relative image paths work no
      -- matter where nvim was started.
      dynamic_root = true,
      sync_scroll = true,
    })
  end,
}
