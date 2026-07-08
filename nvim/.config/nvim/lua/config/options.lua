-- Editor options ported from the previous vim/.vimrc.
local opt = vim.opt

opt.number = true -- show line numbers

-- Indentation: 2-space soft tabs (was `set expandtab` + `retab 2`).
opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2

-- Read-encoding detection order for legacy Japanese files. Neovim is UTF-8
-- internally, so `encoding` itself is left at its default; only this
-- detection list is carried over from the old .vimrc.
opt.fileencodings = { "utf-8", "iso-2022-jp", "ucs-bom", "sjis", "euc-jp", "cp932", "latin1" }
