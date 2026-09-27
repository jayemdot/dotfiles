# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a Stow package that mirrors the target directory structure relative to `$HOME`.

## Deploying dotfiles

Install all packages from the repo root:
```sh
stow bat bin git mise nvim ssh tmux vim yazi zsh
```

Install a single package:
```sh
stow <package>
```

Remove symlinks for a package:
```sh
stow -D <package>
```

Stow creates symlinks in `$HOME` pointing into this repo. For example, `zsh/.zshrc` → `~/.zshrc`.

## Package map

| Directory | Target path(s) |
|-----------|----------------|
| `bat/` | `~/.config/bat/config` |
| `bin/` | `~/.local/bin/` (e.g. `iterm-browser`) |
| `brew/` | `~/.Brewfile` |
| `git/` | `~/.gitconfig` |
| `mise/` | `~/.config/mise/config.toml` |
| `nvim/` | `~/.config/nvim/` |
| `ssh/` | `~/.ssh/config` |
| `tmux/` | `~/.tmux.conf` |
| `vim/` | `~/.vimrc`, `~/.vim/` |
| `yazi/` | `~/.config/yazi/` |
| `zsh/` | `~/.zshrc` |

## Restoring a new machine

The repo ships three scripts:

- `bootstrap.sh` — runs on a clean macOS. Installs Homebrew + Xcode CLT, installs `gh`, runs `gh auth login` (interactive), clones this private repo, and hands off to `setup.sh`.
- `setup.sh` — runs from inside an already-cloned repo (macOS). Idempotent: `brew bundle`, TPM, `stow bat bin git mise nvim ssh tmux vim yazi zsh`, then `mise install` (Node + npm globals like `codex` / `gemini-cli` pinned in `mise/.config/mise/config.toml`).
- `setup-ubuntu.sh` — the apt counterpart for Ubuntu (incl. WSL). Idempotent: apt packages (with `batcat`→`bat` / `fdfind`→`fd` shims in `~/.local/bin`), GitHub-release installs of neovim/yazi/glow into `~/.local/opt`, then the same TPM/hooks/stow/mise/uv flow. The `brew` stow package and `bootstrap.sh` are macOS-only.

One-shot from a fresh terminal (recommended):

```sh
bash <(curl -fsSL https://gist.githubusercontent.com/jayemdot/a5c4129e41cf20af06b6fbe2866d0248/raw/bootstrap.sh)
```

Or, if the repo is already cloned:

```sh
cd ~/dotfiles && ./setup.sh
```

After `setup.sh` finishes: `exec zsh`, then start tmux and press `prefix + I` to install tmux plugins.

## Gist sync (bootstrap.sh)

`bootstrap.sh` is hosted both in this repo (source of truth) and as a public Gist (`a5c4129e41cf20af06b6fbe2866d0248`) so that a fresh macOS can `curl | bash` it before the repo is cloned.

A `post-commit` hook in `.githooks/post-commit` automatically pushes any changes to `bootstrap.sh` up to the Gist. The hook is enabled by `setup.sh` via `git config --local core.hooksPath .githooks`. No manual sync command needed.

## Key configuration notes

- **Shell**: zsh with `zsh-autosuggestions` and `zsh-syntax-highlighting` (installed via Homebrew at `/opt/homebrew/share/`).
- **tmux prefix**: `Ctrl-\` (not the default `Ctrl-b`). Reload config with `prefix + r`.
- **mise** manages Node.js (and globally-installed npm packages like `codex`, `gemini-cli`), plus pnpm/ruby/etc., via `mise/.config/mise/config.toml`. Stow must run before `mise install` so the config is in place — `setup.sh` handles this ordering. **Python is intentionally not in mise.**
- **Python is owned entirely by `uv`**, not mise — interpreters (`uv python install`), per-project venvs/deps (`uv init` / `uv add` / `uv run`, with `pyproject.toml` + `uv.lock`), and global CLI tools (`uv tool install` / `uvx`, e.g. jupyterlab). The default `python` / `python3` on PATH is uv's standalone build (`uv python install 3.14 --default`, landing in `~/.local/bin` which precedes Homebrew), so ad-hoc `python3` and tooling use uv — not the Homebrew pythons (kept only as deps of yt-dlp / python-tk@3.11). Don't `pip install` globally; use `uv tool` / `uv add` / `uv pip`.
- **bat** uses the Monokai Extended Origin theme (`bat/.config/bat/config`). yazi's bat previewer (`yazi/.config/yazi/plugins/bat.yazi`) shows git change markers, tints the background of changed lines, and toggles (`b`) between the file view and a `delta` git-diff view (green add / red delete, deleted lines shown); the diff view needs `git-delta` from Homebrew.
- **yazi** previews text with a custom `bat.yazi` plugin and Markdown with a custom `glow.yazi` plugin (routed in `yazi/.config/yazi/yazi.toml`); both need `bat` and `glow` from Homebrew. `J`/`K` scroll the preview one line at a time. PDFs preview via poppler (`pdftoppm`); `[preview] max_width/max_height` are bumped so pages fill the pane (run `yazi --clear-cache` after changing). Pressing Enter on a PDF opens it in iTerm2's built-in browser via the `iterm-browser` script (`bin` package) for zoom/page navigation. Git status is shown in the file list (VSCode-style `U`/`M`/`A`/`D` signs, configured in `theme.toml` `[git]`, set up in `init.lua`) by `plugins/git.yazi`. This started as the `yazi-rs/plugins:git` plugin but is **vendored** (tracked, not `ya pkg`-managed, files kept read-only) because it carries two `LOCAL PATCH`es on top of upstream: the status sign keeps its color on the hovered row, and git-ignored entries are dimmed via `Entity:style`. Modified files are split into `unstaged` (orange `M`) / `staged` (green `M`) as upstream does. **Re-sync it with upstream after yazi upgrades**: yazi 26.8 changed the fetcher API (fetch must yield per-file results — see upstream's `retry`/`noop`), and the old vendored copy's bare `return false` left `Run fetcher 'git'` tasks stuck forever ("There are unfinished tasks, quit anyway?" on quit, stale signs). To update: fetch upstream `git.yazi/main.lua`, re-apply the `LOCAL PATCH` blocks, `chmod u+w` before writing. The `ya pkg` scaffolding (`package.toml`, `ya pkg install` in `setup.sh`) remains for any future plugins. `theme.toml` follows yazi 26.9's schema (`[mgr]`, `[tabs]`, `[mode]`, `[indicator]`, `[pick]`, …; source of truth: `yazi-config/src/theme/theme.rs`). **Stale section names fail silently** — yazi accepts unknown sections as plugin "custom" sections (how `[git]` works), so after a major yazi upgrade re-check names against `theme.rs` (the old `[manager]`/`[select]` names were silently ignored for months).
- **nvim** is the default editor (`EDITOR=nvim`, `vz` alias), configured in Lua under `nvim/.config/nvim/`. Structure follows the [lazy.nvim](https://github.com/folke/lazy.nvim) recommended layout: `init.lua` → `lua/config/lazy.lua` (bootstraps lazy.nvim into `~/.local/share/nvim/lazy/`, sets `<Space>` leader) → `lua/config/options.lua` (ported `.vimrc` basics: `number`, 2-space soft tabs, `termguicolors`, Japanese `fileencodings`) → `lua/config/keymaps.lua` (Emacs insert/cmdline motion + a `C-k` kill-line reimplemented on the Neovim API, byte-safe for multibyte). Plugin specs live one-per-file in `lua/plugins/` and are auto-imported; `lua/plugins/colorscheme.lua` uses `tanvirtin/monokai.nvim` (classic palette) and clears the background on gutter groups to reproduce the old transparent look. `lazy-lock.json` (plugin version pins) is committed via the stow symlink; the plugins themselves are cloned outside the repo and are not tracked. `neovim` is a Homebrew formula (in `~/.Brewfile`).
- **vim** is retained as a fallback (`vim/` package, `~/.vimrc`, bundled Monokai colorscheme, Vimscript `C-k` kill-line). nvim (above) has superseded it as the default; vim is no longer wired to `EDITOR`.
- **Cross-platform (macOS / Ubuntu / WSL)**: configs are OS-guarded rather than forked. `.zshrc` branches on `$OSTYPE` (`IS_MAC`): Homebrew paths/aliases are macOS-only; zsh plugins and fzf keybindings fall back to apt locations; `o` maps to `open` / `explorer.exe` / `xdg-open`. The clipboard is unified behind `bin/clip-copy` (pbcopy → tmux `load-buffer -w` (OSC 52) → SSH OSC 52 → clip.exe → wl-copy/xclip), used by tmux copy-mode and the `here` alias — copying inside a remote tmux lands on the clipboard of the terminal you're looking at. `ssh/config` guards the Apple-only `UseKeychain` with `IgnoreUnknown`; `iterm-browser` falls back to `wslview`/`xdg-open` outside iTerm2.
- **Locale**: `ja_JP.UTF-8` throughout; Japanese input is handled by Google Japanese IME.

## .gitignore

Private SSH keys (`id_ed25519`, `id_ed25519.pub`) and `.DS_Store` are excluded. Public keys are intentionally not tracked.
