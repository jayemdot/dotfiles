#!/usr/bin/env bash
# Idempotent setup script for an already-cloned dotfiles repo.
# Run from inside the repo: ./setup.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

log() { printf "\033[1;34m==> %s\033[0m\n" "$*"; }

# --- Homebrew packages -------------------------------------------------------
log "Installing Homebrew packages from Brewfile"
brew bundle --file brew/.Brewfile

# --- tmux plugin manager -----------------------------------------------------
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "Installing tmux plugin manager (TPM)"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  log "TPM already installed — skipping"
fi

# --- git hooks ---------------------------------------------------------------
log "Enabling repo-local git hooks (.githooks)"
git config --local core.hooksPath .githooks

# --- stow --------------------------------------------------------------------
# Run stow BEFORE mise install so ~/.config/mise/config.toml is in place.
log "Stowing dotfiles into \$HOME"
stow bat bin git iterm2 kitty mise nvim ssh tmux vim yazi zsh

# --- iTerm2 default profile ---------------------------------------------------
# The "dotfiles" Dynamic Profile (stowed from the iterm2 package, generated from
# terminal/theme.toml) is made the default. Only while iTerm2 is not running —
# a running iTerm2 rewrites its plist on quit and would drop the change.
if [[ -d /Applications/iTerm.app ]]; then
  iterm_guid=$(python3 -c 'import tomllib;print(tomllib.load(open("terminal/theme.toml","rb"))["iterm2"]["guid"])')
  if pgrep -xq iTerm2; then
    log "iTerm2 is running — set the 'dotfiles' profile as default in Settings > Profiles"
  else
    log "Setting iTerm2 default profile to 'dotfiles'"
    defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$iterm_guid"
  fi
fi

# --- mise tools --------------------------------------------------------------
# Installs everything pinned in mise/.config/mise/config.toml (Node, codex,
# gemini-cli, ...). Idempotent — already-installed versions are skipped.
log "Installing mise-managed tools"
mise install

# --- yazi plugins ------------------------------------------------------------
# Installs plugins pinned in yazi/.config/yazi/package.toml (e.g. the git
# status plugin). `ya` ships with yazi (Homebrew). Idempotent.
if command -v ya &>/dev/null; then
  log "Installing yazi plugins (ya pkg install)"
  ya pkg install
else
  log "ya (yazi) not found — skipping yazi plugin install"
fi

# --- uv default Python -------------------------------------------------------
# Make uv's standalone Python the default `python`/`python3` (in ~/.local/bin,
# which precedes Homebrew on PATH). Python is managed by uv, not mise; the
# Homebrew pythons remain only as deps of other formulae.
if command -v uv &>/dev/null; then
  log "Setting uv's Python 3.14 as the default interpreter"
  uv python install 3.14 --default --preview-features python-install-default
fi

log "Setup complete."
cat <<'EOF'

Next steps:
  1. Restart your shell (or run: exec zsh) to pick up the new ~/.zshrc.
  2. Start tmux and press  prefix + I  to install tmux plugins.
  3. (Optional) Generate an SSH key and register it with GitHub:
       ssh-keygen -t ed25519 -C "<your-email>"
       gh ssh-key add ~/.ssh/id_ed25519.pub
EOF
