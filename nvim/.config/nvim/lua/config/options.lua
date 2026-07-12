-- Editor options ported from the previous vim/.vimrc.
local opt = vim.opt

opt.number = true -- show line numbers
opt.termguicolors = true -- 24-bit truecolor, required by the Lua monokai colorscheme

-- Indentation: 2-space soft tabs (was `set expandtab` + `retab 2`).
opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2

-- Cursor shape per mode: block in normal/visual, a vertical bar (beam) in
-- insert, underline in replace. This is identical to Neovim's built-in default,
-- set explicitly so the intent is visible and survives plugin overrides. The
-- shape only changes on the screen if the terminal supports DECSCUSR; iTerm2
-- does, and Neovim emits the sequence through tmux here (TERM is tmux-* and the
-- tmux client advertises the `cstyle` feature).
opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,t:block-blinkon500-blinkoff500-TermCursor"

-- Read-encoding detection order for legacy Japanese files. Neovim is UTF-8
-- internally, so `encoding` itself is left at its default; only this
-- detection list is carried over from the old .vimrc.
opt.fileencodings = { "utf-8", "iso-2022-jp", "ucs-bom", "sjis", "euc-jp", "cp932", "latin1" }
