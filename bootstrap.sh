#!/usr/bin/env bash
# One-shot bootstrap for a clean macOS install.
# Usage (from a fresh terminal):
#   bash <(curl -fsSL https://gist.githubusercontent.com/jayemdot/a5c4129e41cf20af06b6fbe2866d0248/raw/bootstrap.sh)
#
# This handles the parts that must run BEFORE the dotfiles repo exists locally:
#   1. Homebrew (also installs Xcode Command Line Tools → git, curl, make)
#   2. gh CLI + GitHub authentication
#   3. Clones this private dotfiles repo
#   4. Hands off to setup.sh

set -euo pipefail

DOTFILES_REPO="jayemdot/dotfiles"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

log() { printf "\033[1;34m==> %s\033[0m\n" "$*"; }

# --- Homebrew ----------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  log "Installing Homebrew (will also install Xcode Command Line Tools)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "Homebrew already installed — skipping"
fi

# Make brew available in this shell session
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# --- gh CLI ------------------------------------------------------------------
if ! command -v gh &>/dev/null; then
  log "Installing GitHub CLI"
  brew install gh
fi

# --- GitHub auth -------------------------------------------------------------
if ! gh auth status &>/dev/null; then
  log "Authenticating with GitHub (browser device flow)"
  log "Tip: choose HTTPS, and answer 'Yes' to 'Authenticate Git with GitHub credentials'"
  gh auth login
else
  log "Already authenticated with GitHub — skipping"
fi

# --- Clone dotfiles ----------------------------------------------------------
if [[ ! -d "$DOTFILES_DIR" ]]; then
  log "Cloning $DOTFILES_REPO into $DOTFILES_DIR"
  gh repo clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  log "$DOTFILES_DIR already exists — skipping clone"
fi

# --- Hand off to setup.sh ----------------------------------------------------
log "Running setup.sh"
cd "$DOTFILES_DIR"
./setup.sh
