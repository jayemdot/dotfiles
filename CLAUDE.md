# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a Stow package that mirrors the target directory structure relative to `$HOME`.

## Deploying dotfiles

Install all packages from the repo root:
```sh
stow bat git ssh tmux vim zsh
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
| `brew/` | `~/.Brewfile` |
| `git/` | `~/.gitconfig` |
| `ssh/` | `~/.ssh/config` |
| `tmux/` | `~/.tmux.conf` |
| `vim/` | `~/.vimrc`, `~/.vim/` |
| `zsh/` | `~/.zshrc` |

## Restoring a new machine

The repo ships two scripts:

- `bootstrap.sh` — runs on a clean macOS. Installs Homebrew + Xcode CLT, installs `gh`, runs `gh auth login` (interactive), clones this private repo, and hands off to `setup.sh`.
- `setup.sh` — runs from inside an already-cloned repo. Idempotent: `brew bundle`, Volta, TPM, then `stow bat git ssh tmux vim zsh`.

One-shot from a fresh terminal (recommended):

```sh
bash <(curl -fsSL https://gist.githubusercontent.com/jayemdot/a5c4129e41cf20af06b6fbe2866d0248/raw/bootstrap.sh)
```

Or, if the repo is already cloned:

```sh
cd ~/dotfiles && ./setup.sh
```

After `setup.sh` finishes: `exec zsh`, then start tmux and press `prefix + I` to install tmux plugins.

## Key configuration notes

- **Shell**: zsh with `zsh-autosuggestions` and `zsh-syntax-highlighting` (installed via Homebrew at `/opt/homebrew/share/`).
- **tmux prefix**: `Ctrl-\` (not the default `Ctrl-b`). Reload config with `prefix + r`.
- **Volta** manages Node.js/npm versions; `uv` manages Python environments.
- **bat** uses Monokai Extended theme (`bat/.config/bat/config`).
- **vim** uses a custom Emacs-style `C-k` kill-line implementation and the bundled Monokai colorscheme (`vim/.vim/colors/monokai.vim`).
- **Locale**: `ja_JP.UTF-8` throughout; Japanese input is handled by Google Japanese IME.

## .gitignore

Private SSH keys (`id_ed25519`, `id_ed25519.pub`) and `.DS_Store` are excluded. Public keys are intentionally not tracked.
