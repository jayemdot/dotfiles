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
stow bat bin git mise ssh tmux vim yazi zsh

# --- mise tools --------------------------------------------------------------
# Installs everything pinned in mise/.config/mise/config.toml (Node, codex,
# gemini-cli, ...). Idempotent — already-installed versions are skipped.
log "Installing mise-managed tools"
mise install

log "Setup complete."
cat <<'EOF'

Next steps:
  1. Restart your shell (or run: exec zsh) to pick up the new ~/.zshrc.
  2. Start tmux and press  prefix + I  to install tmux plugins.
  3. (Optional) Generate an SSH key and register it with GitHub:
       ssh-keygen -t ed25519 -C "<your-email>"
       gh ssh-key add ~/.ssh/id_ed25519.pub
EOF
