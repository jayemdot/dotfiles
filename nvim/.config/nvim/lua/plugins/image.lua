-- Real images in the split preview (lua/mdpreview) via the kitty graphics
-- protocol (kitty / Ghostty, also through tmux with allow-passthrough).
-- Only the documented API (from_file / from_url / render / clear) is used and
-- every built-in auto-integration is OFF, so nothing is ever drawn into the
-- buffer you are editing. Loaded on demand by lua/mdpreview.
return {
  "3rd/image.nvim",
  version = "*", -- release tags only
  lazy = true,
  opts = {
    backend = "kitty",
    processor = "magick_cli", -- ImageMagick CLI (Homebrew `imagemagick`), no luarocks
    integrations = {
      markdown = { enabled = false },
      asciidoc = { enabled = false },
      neorg = { enabled = false },
      rst = { enabled = false },
      typst = { enabled = false },
      html = { enabled = false },
      css = { enabled = false },
    },
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = true, -- hide images under floats (completion menu, …)
    tmux_show_only_in_active_window = true, -- needs `visual-activity off` (tmux.conf)
    hijack_file_patterns = {}, -- don't take over opening image files
  },
}
