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

# --- Volta -------------------------------------------------------------------
if ! command -v volta &>/dev/null && [[ ! -d "$HOME/.volta" ]]; then
  log "Installing Volta"
  curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
else
  log "Volta already installed — skipping"
fi

# --- tmux plugin manager -----------------------------------------------------
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "Installing tmux plugin manager (TPM)"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  log "TPM already installed — skipping"
fi

# --- stow --------------------------------------------------------------------
log "Stowing dotfiles into \$HOME"
stow bat git ssh tmux vim zsh

log "Setup complete."
cat <<'EOF'

Next steps:
  1. Restart your shell (or run: exec zsh) to pick up the new ~/.zshrc.
  2. Start tmux and press  prefix + I  to install tmux plugins.
  3. (Optional) Generate an SSH key and register it with GitHub:
       ssh-keygen -t ed25519 -C "<your-email>"
       gh ssh-key add ~/.ssh/id_ed25519.pub
EOF
