-- Leader keys must be set before lazy.nvim loads so that plugin key mappings
-- register against the intended leader. Space as leader, `\` as local leader.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Editor options and keymaps (ported from the old .vimrc). Loaded before plugins.
require("config.options")
require("config.keymaps")

-- Bootstrap lazy.nvim: on first launch, clone the stable branch into the data
-- dir (~/.local/share/nvim/lazy/lazy.nvim). This lives outside the dotfiles
-- repo, so nothing here is committed except lazy-lock.json (the version pins).
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Import every plugin spec under lua/plugins/ and start lazy.nvim.
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  -- Built-in colorscheme used only while plugins install on the first run.
  install = { colorscheme = { "habamax" } },
  -- Check for plugin updates in the background; don't nag on startup.
  checker = { enabled = true, notify = false },
})
