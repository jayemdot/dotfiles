-- Emacs-style editing keybindings, ported from the old vim/.vimrc.
-- Cursor motion in insert (i) and command-line (c) modes, plus a C-k kill-line.

local map = vim.keymap.set

-- Cursor motion shared by insert and command-line modes.
local motions = {
  ["<C-p>"] = "<Up>",
  ["<C-n>"] = "<Down>",
  ["<C-f>"] = "<Right>",
  ["<C-b>"] = "<Left>",
  ["<C-a>"] = "<Home>",
  ["<C-e>"] = "<End>",
  ["<C-h>"] = "<BS>",
  ["<C-d>"] = "<Del>",
}
for lhs, rhs in pairs(motions) do
  map({ "i", "c" }, lhs, rhs, { silent = true })
end

-- C-k kill-line (insert mode): delete from the cursor to end of line; if the
-- cursor is already at end of line, pull the next line up (delete the line
-- break). Reimplemented against the Neovim API rather than porting the old
-- column-arithmetic Vimscript. `col` from nvim_win_get_cursor is a 0-indexed
-- byte offset, which is exactly the split point for line:sub().
local function emacs_kill_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col)
  if line:sub(col + 1) ~= "" then
    -- Text remains to the right of the cursor: drop it, keep the line break.
    vim.api.nvim_set_current_line(before)
  elseif row < vim.api.nvim_buf_line_count(0) then
    -- At end of line (or on an empty line): join the next line up.
    local nextline = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
    vim.api.nvim_buf_set_lines(0, row - 1, row + 1, true, { before .. nextline })
  end
  vim.api.nvim_win_set_cursor(0, { row, col })
end
map("i", "<C-k>", emacs_kill_line, { silent = true, desc = "Emacs kill-line" })

-- C-k kill-line (command-line mode): kill from the cursor to end of the command
-- line. Ported verbatim from the old .vimrc idiom.
map("c", "<C-k>", "<Right><C-\\>egetcmdline()[:getcmdpos()-2]<CR><BS>", { silent = false })
