# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a Stow package that mirrors the target directory structure relative to `$HOME`.

## Deploying dotfiles

Install all packages from the repo root:
```sh
stow bat bin git mise ssh tmux vim yazi zsh
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
| `ssh/` | `~/.ssh/config` |
| `tmux/` | `~/.tmux.conf` |
| `vim/` | `~/.vimrc`, `~/.vim/` |
| `yazi/` | `~/.config/yazi/` |
| `zsh/` | `~/.zshrc` |

## Restoring a new machine

The repo ships two scripts:

- `bootstrap.sh` — runs on a clean macOS. Installs Homebrew + Xcode CLT, installs `gh`, runs `gh auth login` (interactive), clones this private repo, and hands off to `setup.sh`.
- `setup.sh` — runs from inside an already-cloned repo. Idempotent: `brew bundle`, TPM, `stow bat bin git mise ssh tmux vim yazi zsh`, then `mise install` (Node + npm globals like `codex` / `gemini-cli` pinned in `mise/.config/mise/config.toml`).

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
- **mise** manages Node.js (and globally-installed npm packages like `codex`, `gemini-cli`) via `mise/.config/mise/config.toml`; `uv` manages Python environments. Stow must run before `mise install` so the config is in place — `setup.sh` handles this ordering.
- **bat** uses the Monokai Extended Origin theme (`bat/.config/bat/config`). yazi's bat previewer (`yazi/.config/yazi/plugins/bat.yazi`) shows git change markers, tints the background of changed lines, and toggles (`b`) between the file view and a `delta` git-diff view (green add / red delete, deleted lines shown); the diff view needs `git-delta` from Homebrew.
- **yazi** previews text with a custom `bat.yazi` plugin and Markdown with a custom `mcat.yazi` plugin (routed in `yazi/.config/yazi/yazi.toml`); both need `bat` and `mcat` from Homebrew. `J`/`K` scroll the preview one line at a time. PDFs preview via poppler (`pdftoppm`); `[preview] max_width/max_height` are bumped so pages fill the pane (run `yazi --clear-cache` after changing). Pressing Enter on a PDF opens it in iTerm2's built-in browser via the `iterm-browser` script (`bin` package) for zoom/page navigation. Git status is shown in the file list (VSCode-style `U`/`M`/`A`/`D` signs, configured in `theme.toml` `[git]`) by the `yazi-rs/plugins:git` plugin — installed via `ya pkg`, pinned in `yazi/.config/yazi/package.toml`, set up in `init.lua`, and restored by `ya pkg install` (in `setup.sh`). The downloaded plugin dir `plugins/git.yazi/` is gitignored; hand-written plugins (`bat.yazi`, `mcat.yazi`) are tracked.
- **vim** uses a custom Emacs-style `C-k` kill-line implementation and the bundled Monokai colorscheme (`vim/.vim/colors/monokai.vim`).
- **Locale**: `ja_JP.UTF-8` throughout; Japanese input is handled by Google Japanese IME.

## .gitignore

Private SSH keys (`id_ed25519`, `id_ed25519.pub`) and `.DS_Store` are excluded. Public keys are intentionally not tracked.
