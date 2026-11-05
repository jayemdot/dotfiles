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
stow bat bin git iterm2 kitty mise nvim ssh tmux vim yazi zed zsh

# --- inputsource (macOS input-source CLI) -------------------------------------
# Built from tools/inputsource.swift (Apple's TIS API only, no third-party
# code). nvim's lua/config/ime.lua calls it to switch the Japanese IME back to
# ABC when leaving insert mode. Rebuilt on every run (cheap, idempotent).
if command -v swiftc &>/dev/null; then
  log "Building inputsource into ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  swiftc -O tools/inputsource.swift -o "$HOME/.local/bin/inputsource"
else
  log "swiftc not found — skipping inputsource (nvim won't switch the IME)"
fi

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

# --- Apps that can't be installed automatically --------------------------------
# Not installable via Homebrew (or disabled there) nor the Mac App Store — e.g.
# the download needs a login. Listed here so a new machine reports what is
# missing; each of these updates itself after the first manual install.
#   "<app path>|<download page>|<why it is manual>"
manual_apps=(
  "/Applications/Muse.app|https://muse.ai/|Meta Muse: login-gated signed download; Homebrew cask 'muse' disabled 2026-10-01"
)
missing_apps=()
for entry in "${manual_apps[@]}"; do
  IFS='|' read -r app url why <<<"$entry"
  [[ -d "$app" ]] || missing_apps+=("     - ${app##*/}: $url  ($why)")
done

log "Setup complete."
cat <<'EOF'

Next steps:
  1. Restart your shell (or run: exec zsh) to pick up the new ~/.zshrc.
  2. Start tmux and press  prefix + I  to install tmux plugins.
  3. (Optional) Generate an SSH key and register it with GitHub:
       ssh-keygen -t ed25519 -C "<your-email>"
       gh ssh-key add ~/.ssh/id_ed25519.pub
EOF
if ((${#missing_apps[@]})); then
  echo "  4. Install these apps by hand (not automatable; they self-update afterwards):"
  printf '%s\n' "${missing_apps[@]}"
fi
