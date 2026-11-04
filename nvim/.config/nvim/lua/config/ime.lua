-- Keep normal-mode commands working with the Japanese IME on.
--
-- With the IME in kana/romaji mode, keystrokes go into IME composition and
-- never reach nvim, so `j`, `dd`, `:w`… do nothing. Whenever nvim ends up in a
-- non-insert context — leaving insert mode or the command line, regaining focus
-- or starting in normal mode — switch the macOS input source to ABC.
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

local group = vim.api.nvim_create_augroup("ime_ascii", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "CmdlineLeave" }, { group = group, callback = M.to_ascii })
vim.api.nvim_create_autocmd({ "FocusGained", "VimEnter" }, {
  group = group,
  callback = function()
    if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
      M.to_ascii()
    end
  end,
})

return M
