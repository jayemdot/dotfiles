-- Monokai colorscheme, replacing the old bundled vim/.vim/colors/monokai.vim.
-- tanvirtin/monokai.nvim's default palette is the classic Monokai, matching the
-- previous look. It has no built-in transparency option, so the old .vimrc's
-- `highlight Normal guibg=NONE ctermbg=NONE` is reproduced by clearing the
-- background on the gutter/background groups after setup — popups (Pmenu,
-- NormalFloat) intentionally keep their background so they stay readable.
return {
  {
    "tanvirtin/monokai.nvim",
    lazy = false, -- a colorscheme should load on startup...
    priority = 1000, -- ...and before other plugins so the first paint is themed.
    config = function()
      require("monokai").setup({}) -- no palette = classic Monokai; applies the theme

      -- Transparent background: clear the background on the gutter/background
      -- groups so the terminal shows through. nvim_set_hl *replaces* a group
      -- rather than merging, so read the existing highlight first and override
      -- only bg — otherwise the foreground color would be wiped too.
      for _, group in ipairs({
        "Normal",
        "NormalNC",
        "SignColumn",
        "EndOfBuffer",
        "LineNr",
        "FoldColumn",
      }) do
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
        hl.bg = "none"
        vim.api.nvim_set_hl(0, group, hl)
      end
    end,
  },
}
