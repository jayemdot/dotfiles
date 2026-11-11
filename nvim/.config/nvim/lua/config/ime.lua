-- Keep normal-mode commands working with the Japanese IME on.
--
-- With the IME in kana/romaji mode, keystrokes go into IME composition and
-- never reach nvim, so `j`, `dd`, `:w`… do nothing. Whenever nvim ends up in
-- normal (or another non-typing) mode — after leaving insert mode or the
-- command line, regaining focus or starting up — switch the macOS input
-- source to ABC. Typing modes are never touched (see settle_then_ascii).
--
-- Uses `inputsource` (tools/inputsource.swift, built into ~/.local/bin by
-- setup.sh; only Apple's TIS API). Looked up at call time, so it silently does
-- nothing where it's missing (Ubuntu, SSH sessions, not built yet).
local M = {}

M.ASCII = "com.apple.keylayout.ABC"

-- Only an nvim with a UI attached is typed into. Headless instances (tests,
-- scripts, LSP tooling) must never touch the user's input source.
function M.has_ui()
  return #vim.api.nvim_list_uis() > 0
end

function M.to_ascii()
  if not M.has_ui() or vim.fn.executable("inputsource") ~= 1 then
    return
  end
  -- Async: never blocks leaving insert mode. Only switch when needed.
  vim.system({ "inputsource" }, { text = true }, function(r)
    if r.code == 0 and vim.trim(r.stdout) ~= M.ASCII then
      vim.system({ "inputsource", M.ASCII })
    end
  end)
end

-- Decide once the event has settled, not when it fires: mappings pass through
-- other modes while the user stays in insert mode — bullets.vim's <CR> runs
-- `<C-R>=…` (an expression command-line, so CmdlineLeave fires on every
-- newline in a markdown list), `<C-o>:cmd` hops out and back. Switching then
-- would kick the user out of kana input mid-sentence. So: schedule, then only
-- switch if nvim is really outside insert / replace / command-line / terminal.
local function settle_then_ascii()
  vim.schedule(function()
    local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
    if mode ~= "i" and mode ~= "R" and mode ~= "c" and mode ~= "t" then
      M.to_ascii()
    end
  end)
end

local group = vim.api.nvim_create_augroup("ime_ascii", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave", "FocusGained", "VimEnter" }, {
  group = group,
  callback = settle_then_ascii,
})

return M
