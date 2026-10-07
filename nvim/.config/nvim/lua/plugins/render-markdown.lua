-- Pretty-rendered Markdown, used for the right-hand split preview
-- (lua/mdpreview). Buffers backed by a file — the ones you edit — stay plain
-- text; only nofile buffers (the preview, LSP hover docs) are rendered.
return {
  "MeanderingProgrammer/render-markdown.nvim",
  version = "8.*", -- release tags only; a new major version is a deliberate bump
  ft = "markdown",
  opts = {
    ignore = function(buf)
      return vim.bo[buf].buftype == ""
    end,
    -- The preview is never focused, but rendering follows the *global* mode:
    -- without insert/visual modes here the preview would turn raw while you
    -- type on the left.
    render_modes = true,
    -- The preview's cursor only mirrors the source's; never un-render that line.
    anti_conceal = { enabled = false },
  },
}
