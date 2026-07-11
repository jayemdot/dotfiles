-- Autocommands.

-- Force 2-space indentation across filetypes. Neovim's bundled filetype plugins
-- set their own widths (e.g. Python → 4); this FileType autocmd runs after the
-- ftplugin and re-applies 2 spaces so indentation is uniform everywhere. The
-- global options.lua already sets these, but they get overridden per-filetype
-- without this. Filetypes whose syntax requires real tabs are skipped (Makefiles
-- break with spaces; Go is formatted with tabs by gofmt).
local keep_tabs = { make = true, go = true }
vim.api.nvim_create_autocmd("FileType", {
  desc = "Force 2-space indentation (except tab-required filetypes)",
  callback = function(ev)
    if keep_tabs[vim.bo[ev.buf].filetype] then
      return
    end
    local bo = vim.bo[ev.buf]
    bo.expandtab = true
    bo.tabstop = 2
    bo.shiftwidth = 2
    bo.softtabstop = 2
  end,
})
