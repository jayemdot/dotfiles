-- Markdown tables are realigned automatically as you type `|` (table mode is
-- switched on for markdown buffers in after/ftplugin/markdown.lua). Column
-- widths use display width, so Japanese text lines up.
-- Default maps live under <leader>t (e.g. <leader>tr realign, <leader>tdd delete row).
return {
  "dhruvasagar/vim-table-mode",
  version = "*",
  ft = "markdown",
  init = function()
    vim.g.table_mode_corner = "|" -- `|---|---|` separators (Markdown-compatible)
  end,
}
