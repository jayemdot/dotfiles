-- Completion: LSP (marksman: links, headings), file paths, words in the buffer.
-- Paths are relative to the current file's directory, so typing `./` or `img/`
-- inside `![](…)` / `[](…)` suggests what's actually next to the document.
return {
  "saghen/blink.cmp",
  version = "1.*", -- release tags ship the prebuilt fuzzy-matcher binary
  lazy = false, -- must be loaded before LSP clients start (completion capabilities)
  opts = {
    keymap = {
      -- <C-y> accept, <C-n>/<C-p> select, <C-e> close, <C-space> open, <C-b>/<C-f>
      -- scroll docs. Each falls back to the Emacs-style insert keys
      -- (lua/config/keymaps.lua) when the menu isn't open.
      preset = "default",
      -- Keep <C-k> as kill-line rather than signature help.
      ["<C-k>"] = false,
      -- Leave <Tab>/<S-Tab> to buffer keymaps (markdown: indent/outdent the
      -- line, after/ftplugin/markdown.lua). blink re-applies its own buffer-local
      -- maps on every InsertEnter, and its fallback runs a non-expr callback via
      -- vim.schedule, i.e. *after* the keys typed next. Its Tab only jumps
      -- snippet placeholders, and no source here produces snippets.
      ["<Tab>"] = false,
      ["<S-Tab>"] = false,
    },
    sources = { default = { "lsp", "path", "buffer" } },
    completion = { documentation = { auto_show = true } },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
}
