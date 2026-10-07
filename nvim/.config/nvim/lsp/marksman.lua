-- Markdown language server: link/heading completion, go-to-definition on
-- links (<C-]>), broken-link diagnostics, document outline (gO).
-- Installed by mise (mise/.config/mise/config.toml); enabled in lua/config/lsp.lua.
-- Read by Neovim's built-in LSP config (:h lsp-config), no nvim-lspconfig needed.
return {
  cmd = { "marksman", "server" },
  filetypes = { "markdown" },
  -- Attach only to real files: the split preview (lua/mdpreview) is also a
  -- markdown buffer, but a nofile scratch copy that must not get diagnostics.
  root_dir = function(bufnr, on_dir)
    if vim.bo[bufnr].buftype ~= "" then
      return
    end
    local name = vim.api.nvim_buf_get_name(bufnr)
    on_dir(vim.fs.root(bufnr, { ".marksman.toml", ".git" }) or vim.fs.dirname(name))
  end,
}
