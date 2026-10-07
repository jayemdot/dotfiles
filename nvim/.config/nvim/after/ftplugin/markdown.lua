-- Markdown editing setup. Runs for every markdown buffer, including the
-- scratch copy shown by the split preview — leave those alone.
if vim.bo.buftype ~= "" then
  return
end

-- The left side is raw text: soft-wrap prose, no concealment.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.conceallevel = 0
vim.opt_local.spell = false

local preview = require("mdpreview")
local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = true, desc = desc })
end
map("<leader>mp", preview.toggle, "Markdown: toggle split preview")
map("<leader>mb", "<cmd>LivePreview start<cr>", "Markdown: open browser preview")
map("<leader>mB", "<cmd>LivePreview close<cr>", "Markdown: close browser preview")
map("<leader>mi", "<cmd>PasteImage<cr>", "Markdown: paste image from clipboard")
-- <leader>mx (toggle checkbox) comes from lua/plugins/bullets.lua.

-- Tables realign as you type `|`; also realign when leaving insert mode.
vim.cmd("silent! TableModeEnable")
vim.api.nvim_create_autocmd("InsertLeave", {
  buffer = 0,
  callback = function()
    if vim.api.nvim_get_current_line():match("^%s*|") then
      vim.cmd("silent! TableModeRealign")
    end
  end,
})

-- Open the preview automatically when there is room for two columns.
-- Set `vim.g.mdpreview_auto = false` to only open it with <leader>mp.
if vim.g.mdpreview_auto ~= false then
  local buf = vim.api.nvim_get_current_buf()
  local function auto_open()
    if vim.o.columns >= 120 and vim.api.nvim_get_current_buf() == buf then
      preview.open(buf)
    end
  end
  vim.api.nvim_create_autocmd("BufWinEnter", { buffer = buf, callback = vim.schedule_wrap(auto_open) })
  vim.schedule(auto_open)
end
