-- Smoke test for the nvim Markdown setup. Run after plugin/nvim upgrades:
--
--     nvim --headless -c "luafile tests/nvim-markdown.lua"
--
-- Exits 0 when every check passes, 1 otherwise. Uses a throwaway fixture in a
-- temp dir; your files are not touched. Image *drawing* needs a real kitty
-- window and is not covered here (only the image.nvim API surface is).

local results, failed = {}, 0
local function check(name, ok, detail)
  results[#results + 1] = ("%s %s%s"):format(ok and "ok  " or "FAIL", name, (not ok and detail) and (" — " .. detail) or "")
  if not ok then
    failed = failed + 1
  end
end
local function wait(ms, cond)
  return vim.wait(ms, cond or function()
    return false
  end, 20)
end

local dir -- fixture directory (cleaned up in the report section)
local function main()
-- Fixture -------------------------------------------------------------------
dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/img", "p")
local md = dir .. "/doc.md"
vim.fn.writefile({
  "# Title",
  "",
  "![pic](img/a.png)",
  "",
  "- first",
}, md)
vim.o.columns = 80 -- below the auto-open threshold: open explicitly below
vim.cmd.edit(md)
local src, srcwin = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()

-- Plugins / LSP ---------------------------------------------------------------
for _, mod in ipairs({ "render-markdown", "blink.cmp", "livepreview.config", "img-clip" }) do
  check("plugin loads: " .. mod, pcall(require, mod))
end
-- image.nvim's kitty backend needs a real terminal on stdout; when this test's
-- output is redirected its setup fails, so only check the API in a terminal.
local img_ok, img = false, nil
if vim.uv.guess_handle(1) == "tty" then
  img_ok, img = pcall(require, "image")
end
if img_ok then
  check("image.nvim API: from_file/from_url", type(img.from_file) == "function" and type(img.from_url) == "function")
else
  results[#results + 1] = "skip image.nvim API (stdout is not a terminal)"
end
check("marksman on PATH", vim.fn.executable("marksman") == 1)
wait(5000, function()
  return #vim.lsp.get_clients({ bufnr = src, name = "marksman" }) > 0
end)
check("marksman attached to the file", #vim.lsp.get_clients({ bufnr = src, name = "marksman" }) > 0)

-- Split preview -----------------------------------------------------------------
local preview = require("mdpreview")
preview.open(src)
local pwin
for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  if w ~= srcwin then
    pwin = w
  end
end
check("preview window opened", pwin ~= nil)
local pbuf = pwin and vim.api.nvim_win_get_buf(pwin)
if pbuf then
  local same = vim.deep_equal(vim.api.nvim_buf_get_lines(src, 0, -1, false), vim.api.nvim_buf_get_lines(pbuf, 0, -1, false))
  check("preview mirrors the file", same)
  check("preview is read-only scratch", vim.bo[pbuf].buftype == "nofile" and not vim.bo[pbuf].modifiable)
  check("preview is right of the file", vim.api.nvim_win_get_position(pwin)[2] > vim.api.nvim_win_get_position(srcwin)[2])

  -- one-way sync: edit the file, the preview follows
  vim.api.nvim_buf_set_lines(src, 1, 1, false, { "added line" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = src })
  local synced = wait(2000, function()
    return vim.api.nvim_buf_get_lines(pbuf, 1, 2, false)[1] == "added line"
  end)
  check("edits sync left -> right", synced)

  -- rendering only on the right, LSP only on the left
  wait(1000)
  local function rm_marks(buf)
    local n = 0
    for name, ns in pairs(vim.api.nvim_get_namespaces()) do
      if name:find("render%-markdown") then
        n = n + #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
      end
    end
    return n
  end
  check("render-markdown renders the preview", rm_marks(pbuf) > 0, "no extmarks")

  -- the render must follow edits, not just exist: a heading added to the file
  -- has to get render-markdown marks on its (new) line in the preview
  local function rm_marks_on(buf, row)
    local n = 0
    for name, ns in pairs(vim.api.nvim_get_namespaces()) do
      if name:find("render%-markdown") then
        n = n + #vim.api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, {})
      end
    end
    return n
  end
  local row = vim.api.nvim_buf_line_count(src)
  vim.api.nvim_buf_set_lines(src, row, row, false, { "", "## Fresh heading" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = src })
  local fresh = wait(2000, function()
    return rm_marks_on(pbuf, row + 1) > 0
  end)
  check("preview re-renders after an edit", fresh, "new heading line has no marks (stale render)")
  vim.api.nvim_buf_set_lines(src, row, row + 2, false, {})
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = src })
  wait(300)
  check("render-markdown leaves the file raw", rm_marks(src) == 0, rm_marks(src) .. " extmarks")
  check("no LSP on the preview", #vim.lsp.get_clients({ bufnr = pbuf }) == 0)

  -- typing on the left (insert mode) must not un-render the preview
  -- (<Cmd> runs the probe without leaving insert mode; vim.wait inside it lets
  -- the debounced sync and render-markdown's render run while mode() is "i")
  local in_insert, marks_in_insert = false, 0
  _G.__mdpreview_probe = function()
    in_insert = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
    vim.api.nvim_buf_set_lines(src, -1, -1, false, { "typing..." })
    vim.api.nvim_exec_autocmds("TextChangedI", { buffer = src })
    vim.wait(1000)
    marks_in_insert = rm_marks(pbuf)
  end
  vim.api.nvim_feedkeys(vim.keycode("Go<Cmd>lua _G.__mdpreview_probe()<CR><Esc>"), "x", false)
  check("preview stays rendered while typing", in_insert and marks_in_insert > 0, "insert=" .. tostring(in_insert) .. " marks=" .. marks_in_insert)
  vim.api.nvim_buf_set_lines(src, -3, -1, false, {}) -- drop the probe lines
  wait(100)

  -- focus bounces back: the preview can't be edited
  vim.api.nvim_set_current_win(pwin)
  wait(200)
  check("focus returns to the file", vim.api.nvim_get_current_win() == srcwin)

  preview.close(src)
  check("preview closes cleanly", not vim.api.nvim_win_is_valid(pwin) and not vim.api.nvim_buf_is_valid(pbuf))
end

-- Lists (bullets.vim) -------------------------------------------------------------
vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(src), 0 })
vim.api.nvim_feedkeys(vim.keycode("A<CR>second<Esc>"), "x", false)
local last = vim.api.nvim_buf_get_lines(src, -2, -1, false)[1]
check("<CR> continues a bullet list", last == "- second", vim.inspect(last))

-- Tables (vim-table-mode, Japanese display width) ---------------------------------
local tl = vim.api.nvim_buf_line_count(src)
vim.api.nvim_buf_set_lines(src, tl, tl, false, { "", "| 名前 | x |", "|---|---|", "| a | 日本語テキスト |" })
vim.api.nvim_win_set_cursor(0, { tl + 2, 0 })
vim.cmd("TableModeRealign")
local rows = vim.api.nvim_buf_get_lines(src, tl + 1, tl + 4, false)
local function bar_cols(line)
  local cols, col = {}, 0
  for ch in line:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if ch == "|" then
      cols[#cols + 1] = col
    end
    col = col + vim.fn.strdisplaywidth(ch)
  end
  return table.concat(cols, ",")
end
local aligned = bar_cols(rows[1]) == bar_cols(rows[2]) and bar_cols(rows[2]) == bar_cols(rows[3])
check("table realigns by display width (日本語)", aligned, table.concat(rows, " / "))

-- Browser preview server -------------------------------------------------------------
LivePreview.config.browser = "true" -- don't open a browser during the test
vim.cmd("LivePreview start")
local up = wait(5000, function()
  local r = vim.system({ "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "http://127.0.0.1:5500/doc.md" }, { text = true }):wait()
  return r.stdout == "200"
end)
check("LivePreview serves the document", up)
vim.cmd("LivePreview close")

end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  check("test script ran to completion", false, err)
end

-- Report ------------------------------------------------------------------------------
pcall(function()
  vim.cmd("silent! stopinsert")
  vim.cmd("silent! bufdo set nomodified")
end)
print(table.concat(results, "\n") .. ("\n\n%d passed, %d failed"):format(#results - failed, failed))
pcall(vim.fn.delete, dir, "rf")
vim.cmd(failed == 0 and "qa!" or "cq!")
