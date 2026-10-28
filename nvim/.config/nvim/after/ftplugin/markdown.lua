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

-- Tab / Shift-Tab while typing: shift the current line's leading whitespace by
-- exactly one 'shiftwidth' (2 here), e.g. to nest or un-nest a list item, and
-- keep the cursor on the same character. <C-i> too: kitty + tmux extended keys
-- can report it separately from <Tab>.
-- Deliberately not Vim's i_CTRL-T / i_CTRL-D: they round the indent to a
-- multiple of 'shiftwidth', and CTRL-D right after a typed `0` or `^` deletes
-- ALL indent ("item 10" + Shift-Tab would lose the 0 and the indent).
-- Buffer-local, so it wins over blink.cmp's global <Tab> (snippet jump).
local function shift_line(delta)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local lead = line:match("^[ \t]*")
  local new_lead = string.rep(" ", math.max(0, vim.fn.strdisplaywidth(lead) + delta))
  if new_lead == lead then
    return
  end
  vim.api.nvim_set_current_line(new_lead .. line:sub(#lead + 1))
  local new_col = col >= #lead and col - #lead + #new_lead or math.min(col, #new_lead)
  vim.api.nvim_win_set_cursor(0, { row, new_col })
end
for _, lhs in ipairs({ "<Tab>", "<C-i>" }) do
  vim.keymap.set("i", lhs, function()
    shift_line(vim.fn.shiftwidth())
  end, { buffer = true, desc = "Markdown: indent line" })
end
vim.keymap.set("i", "<S-Tab>", function()
  shift_line(-vim.fn.shiftwidth())
end, { buffer = true, desc = "Markdown: outdent line" })

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
