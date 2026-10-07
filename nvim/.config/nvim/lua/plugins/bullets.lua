-- List editing: <CR> / o continue bullets and numbered lists (an empty item
-- ends the list), gN renumbers, >> / << (and insert <C-t>) change the level,
-- <leader>mx toggles a [ ] checkbox.
-- The plugin's default maps are off: its insert-mode <C-d> would shadow the
-- Emacs-style <C-d> (delete char) from lua/config/keymaps.lua.
return {
  "bullets-vim/bullets.vim",
  version = "*",
  ft = { "markdown", "text", "gitcommit" },
  init = function()
    vim.g.bullets_enabled_file_types = { "markdown", "text", "gitcommit" }
    vim.g.bullets_set_mappings = 0
    vim.g.bullets_custom_mappings = {
      { "imap", "<cr>", "<Plug>(bullets-newline)" },
      { "inoremap", "<C-cr>", "<cr>" },
      { "nmap", "o", "<Plug>(bullets-newline)" },
      { "vmap", "gN", "<Plug>(bullets-renumber)" },
      { "nmap", "gN", "<Plug>(bullets-renumber)" },
      { "nmap", "<leader>mx", "<Plug>(bullets-toggle-checkbox)" },
      { "imap", "<C-t>", "<Plug>(bullets-demote)" },
      { "nmap", ">>", "<Plug>(bullets-demote)" },
      { "vmap", ">", "<Plug>(bullets-demote)" },
      { "nmap", "<<", "<Plug>(bullets-promote)" },
      { "vmap", "<", "<Plug>(bullets-promote)" },
    }
  end,
}
