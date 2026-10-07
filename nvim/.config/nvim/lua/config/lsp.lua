-- Language servers. Each server's config lives in lsp/<name>.lua (:h lsp-config).
-- Neovim's default LSP keymaps cover the rest (K hover, grn rename, grr refs,
-- gO outline, <C-]> go to definition / follow link).
vim.lsp.enable({ "marksman" })
