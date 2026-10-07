-- Paste an image from the clipboard: saves it to ./assets/ next to the
-- document and inserts `![](assets/….png)`. <leader>mi.
-- Needs `pngpaste` on macOS (Brewfile), xclip / wl-clipboard on Linux.
return {
  "HakonHarnes/img-clip.nvim",
  version = "*",
  cmd = "PasteImage",
  opts = {
    default = {
      dir_path = "assets",
      relative_to_current_file = true,
      prompt_for_file_name = false, -- timestamped name; rename later if wanted
    },
  },
}
