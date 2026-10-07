-- Side-by-side Markdown preview.
--
-- The file buffer on the left is the single source of truth. The right-hand
-- window shows a read-only scratch copy that is synced one way (left -> right)
-- on every edit, scrolled along with the left window, rendered by
-- render-markdown.nvim (it only attaches to nofile buffers, see
-- lua/plugins/render-markdown.lua), and decorated with real images through
-- image.nvim when the terminal speaks the kitty graphics protocol.
--
-- Deliberately built only on core Neovim APIs and the *documented* APIs of the
-- two plugins (render-markdown: `ignore`/`render_modes` options; image.nvim:
-- from_file / from_url / render / clear), so plugin upgrades can't silently
-- break the glue.
--
-- :MdPreview [toggle|open|close]   (mapped to <leader>mp in markdown buffers)

local M = {}

local SYNC_DELAY_MS = 150

---@class mdpreview.State
---@field src integer source (file) buffer
---@field srcwin integer window showing the source
---@field buf integer preview scratch buffer
---@field win integer preview window
---@field group integer autocmd group
---@field timer uv.uv_timer_t
---@field graphics boolean draw images (kitty graphics protocol available)
---@field images table[] image.nvim Image objects currently placed
---@field image_sig string? identity of the placed set, to skip redundant redraws

---@type table<integer, mdpreview.State> keyed by source buffer
local states = {}

local function valid_win(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w)
end

local function valid_buf(b)
  return b ~= nil and vim.api.nvim_buf_is_valid(b)
end

-- Can the terminal show images? Inside tmux, ask tmux for the attached client's
-- terminal: a pane's own $TERM is tmux-256color and its env may predate the
-- current client (e.g. a pane created from iTerm2, now attached from kitty).
local function kitty_graphics()
  local term
  if vim.env.TMUX then
    local res = vim.system({ "tmux", "display", "-p", "#{client_termname}" }, { text = true }):wait()
    term = res.code == 0 and vim.trim(res.stdout) or ""
  else
    term = vim.env.TERM or ""
  end
  return term:find("kitty", 1, true) ~= nil or term:find("ghostty", 1, true) ~= nil
end

-- Image references `![alt](url "title")` outside fenced code blocks.
---@return { row: integer, col: integer, url: string }[] row/col are 0-based
local function find_images(lines)
  local found, fence = {}, nil
  for i, line in ipairs(lines) do
    local f = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if f then
      if not fence then
        fence = f:sub(1, 1)
      elseif f:sub(1, 1) == fence then
        fence = nil
      end
    elseif not fence then
      local init = 1
      while true do
        local s, e, url = line:find("!%[[^%]]*%]%(%s*<?([^%s>%)]+)>?[^%)]*%)", init)
        if not s then
          break
        end
        found[#found + 1] = { row = i - 1, col = s - 1, url = url }
        init = e + 1
      end
    end
  end
  return found
end

-- Resolve an image URL the way a Markdown renderer would: relative to the
-- source file's directory. Returns the path/URL and whether it is remote.
local function resolve(src, url)
  url = url:gsub("%%(%x%x)", function(h)
    return string.char(tonumber(h, 16))
  end)
  if url:match("^%a[%w+.-]*://") then
    return url, true
  end
  if url:sub(1, 1) == "~" or url:sub(1, 1) == "/" then
    return vim.fs.normalize(url), false
  end
  return vim.fs.normalize(vim.fs.dirname(vim.api.nvim_buf_get_name(src)) .. "/" .. url), false
end

local function clear_images(st)
  for _, img in ipairs(st.images) do
    pcall(img.clear, img)
  end
  st.images = {}
end

local function update_images(st, lines)
  if not st.graphics then
    return
  end
  local found = find_images(lines)
  local parts = {}
  for _, f in ipairs(found) do
    parts[#parts + 1] = ("%d:%d:%s"):format(f.row, f.col, f.url)
  end
  local sig = table.concat(parts, "\n")
  if sig == st.image_sig then
    return -- same images on the same lines: the existing placements are still right
  end
  st.image_sig = sig
  clear_images(st)

  local ok, api = pcall(require, "image")
  if not ok then
    return
  end
  for _, f in ipairs(found) do
    local path, remote = resolve(st.src, f.url)
    local opts = { window = st.win, buffer = st.buf, with_virtual_padding = true }
    local function place(img)
      if img and states[st.src] == st and st.image_sig == sig then
        st.images[#st.images + 1] = img
        img:render({ x = f.col, y = f.row })
      end
    end
    if remote then
      pcall(api.from_url, path, opts, place)
    elseif vim.uv.fs_stat(path) then
      local okf, img = pcall(api.from_file, path, opts)
      if okf then
        place(img)
      end
    end
  end
end

-- Keep the preview at the same place as the source window.
local function sync_scroll(st)
  if not (valid_win(st.srcwin) and valid_win(st.win)) then
    return
  end
  local top = vim.fn.line("w0", st.srcwin)
  local cur = vim.api.nvim_win_get_cursor(st.srcwin)[1]
  local last = vim.api.nvim_buf_line_count(st.buf)
  vim.api.nvim_win_call(st.win, function()
    pcall(vim.api.nvim_win_set_cursor, st.win, { math.min(cur, last), 0 })
    vim.fn.winrestview({ topline = math.min(top, last) })
  end)
  -- render-markdown renders the visible range; let it see the new viewport.
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = st.buf })
end

-- Copy the source into the preview. Only the changed middle range is replaced
-- (common prefix/suffix kept), so marks on untouched lines — including image
-- placements — survive edits elsewhere.
local function sync(st)
  if not (valid_buf(st.src) and valid_buf(st.buf)) then
    return M.close(st.src)
  end
  local new = vim.api.nvim_buf_get_lines(st.src, 0, -1, false)
  local old = vim.api.nvim_buf_get_lines(st.buf, 0, -1, false)
  local n_old, n_new = #old, #new
  local p = 0
  while p < n_old and p < n_new and old[p + 1] == new[p + 1] do
    p = p + 1
  end
  local s = 0
  while s < n_old - p and s < n_new - p and old[n_old - s] == new[n_new - s] do
    s = s + 1
  end
  if not (p == n_old and p == n_new) then
    vim.bo[st.buf].modifiable = true
    vim.api.nvim_buf_set_lines(st.buf, p, n_old - s, false, vim.list_slice(new, p + 1, n_new - s))
    vim.bo[st.buf].modifiable = false
    -- Neovim only fires TextChanged for the *current* buffer, so a background
    -- edit of the preview would leave render-markdown's marks stale. Fire it on
    -- the preview explicitly — the same thing render-markdown's own
    -- `:RenderMarkdown preview` does (core/preview.lua, copy_event).
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = st.buf })
  end
  update_images(st, new)
  sync_scroll(st)
end

local function schedule_sync(st)
  st.timer:stop()
  st.timer:start(
    SYNC_DELAY_MS,
    0,
    vim.schedule_wrap(function()
      if states[st.src] == st then
        sync(st)
      end
    end)
  )
end

function M.is_open(src)
  return states[src or vim.api.nvim_get_current_buf()] ~= nil
end

function M.close(src)
  src = src or vim.api.nvim_get_current_buf()
  local st = states[src]
  if not st then
    return
  end
  states[src] = nil
  pcall(vim.api.nvim_del_augroup_by_id, st.group)
  st.timer:stop()
  st.timer:close()
  clear_images(st)
  if valid_win(st.win) then
    pcall(vim.api.nvim_win_close, st.win, true)
  end
  if valid_buf(st.buf) then
    pcall(vim.api.nvim_buf_delete, st.buf, { force = true })
  end
end

function M.open(src)
  src = src or vim.api.nvim_get_current_buf()
  if states[src] or vim.bo[src].filetype ~= "markdown" or vim.bo[src].buftype ~= "" then
    return
  end
  local srcwin = vim.api.nvim_get_current_buf() == src and vim.api.nvim_get_current_win() or vim.fn.bufwinid(src)
  if srcwin == -1 then
    return
  end

  local buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch (buftype=nofile)
  vim.bo[buf].bufhidden = "wipe"
  pcall(vim.api.nvim_buf_set_name, buf, "mdpreview://" .. vim.api.nvim_buf_get_name(src))
  local win = vim.api.nvim_open_win(buf, false, { split = "right", win = srcwin })
  local wo = {
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    list = false,
    spell = false,
    wrap = true,
    linebreak = true,
    breakindent = true,
    cursorline = true, -- marks the line the cursor is on in the source
    winfixbuf = true, -- nothing else can be loaded into the preview window
    statusline = " preview: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(src), ":t"):gsub("%%", "%%%%"),
  }
  for k, v in pairs(wo) do
    vim.wo[win][k] = v
  end
  vim.bo[buf].filetype = "markdown" -- render-markdown attaches (nofile buffers only)

  local st = {
    src = src,
    srcwin = srcwin,
    buf = buf,
    win = win,
    group = vim.api.nvim_create_augroup("mdpreview." .. src, { clear = true }),
    timer = assert(vim.uv.new_timer()),
    graphics = kitty_graphics(),
    images = {},
  }
  states[src] = st

  local au = vim.api.nvim_create_autocmd
  au({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = st.group,
    buffer = src,
    callback = function()
      schedule_sync(st)
    end,
  })
  au({ "CursorMoved", "CursorMovedI" }, {
    group = st.group,
    buffer = src,
    callback = function()
      if vim.api.nvim_get_current_win() == st.srcwin then
        sync_scroll(st)
      end
    end,
  })
  au("WinScrolled", {
    group = st.group,
    pattern = tostring(srcwin),
    callback = function()
      sync_scroll(st)
    end,
  })
  -- Read-only view: focus never stays in the preview (mouse-wheel scrolling an
  -- unfocused window still works). Editing happens only on the left.
  au("WinEnter", {
    group = st.group,
    callback = function()
      if vim.api.nvim_get_current_win() == st.win and valid_win(st.srcwin) then
        vim.schedule(function()
          if valid_win(st.srcwin) then
            vim.api.nvim_set_current_win(st.srcwin)
          end
        end)
      end
    end,
  })
  -- `:q` in the source window should quit as if the preview weren't there.
  au("QuitPre", {
    group = st.group,
    callback = function()
      if vim.api.nvim_get_current_win() == st.srcwin then
        M.close(src)
      end
    end,
  })
  au("WinClosed", {
    group = st.group,
    pattern = { tostring(win), tostring(srcwin) },
    callback = function()
      vim.schedule(function()
        M.close(src)
      end)
    end,
  })
  au({ "BufWinLeave", "BufUnload" }, {
    group = st.group,
    buffer = src,
    callback = function()
      vim.schedule(function()
        M.close(src)
      end)
    end,
  })

  sync(st)
end

function M.toggle(src)
  src = src or vim.api.nvim_get_current_buf()
  if states[src] then
    M.close(src)
  else
    M.open(src)
  end
end

vim.api.nvim_create_user_command("MdPreview", function(opts)
  local action = opts.fargs[1] or "toggle"
  if not M[action] or action == "is_open" then
    return vim.notify("MdPreview: unknown action " .. action, vim.log.levels.ERROR)
  end
  M[action]()
end, {
  nargs = "?",
  complete = function()
    return { "toggle", "open", "close" }
  end,
  desc = "Side-by-side Markdown preview",
})

return M
