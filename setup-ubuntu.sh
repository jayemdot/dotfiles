#!/usr/bin/env bash
# Idempotent setup script for Ubuntu (incl. WSL) — the apt counterpart of
# setup.sh (macOS / Homebrew). Run from inside the cloned repo:
#   cd ~/dotfiles && ./setup-ubuntu.sh
#
# Tools missing from (or too old in) the Ubuntu archive — neovim, yazi, glow —
# are installed from their official GitHub releases into ~/.local/{bin,opt}.
# The `brew` stow package (Brewfile) and bootstrap.sh are macOS-only.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

log()  { printf "\033[1;34m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m==> WARN: %s\033[0m\n" "$*"; }

arch=$(uname -m) # x86_64 / aarch64
mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
export PATH="$HOME/.local/bin:$PATH"

# --- apt packages --------------------------------------------------------------
log "Installing apt packages"
sudo apt-get update
sudo apt-get install -y \
  zsh git git-lfs stow tmux curl unzip jq ca-certificates \
  bat fd-find ripgrep poppler-utils \
  zsh-autosuggestions zsh-syntax-highlighting \
  language-pack-ja

# Japanese locale (zshrc exports LANG/LC_ALL=ja_JP.UTF-8)
sudo locale-gen ja_JP.UTF-8 >/dev/null || warn "locale-gen ja_JP.UTF-8 failed"

# --- Ubuntu package-name shims -------------------------------------------------
# Ubuntu ships bat as `batcat` and fd as `fdfind` (name-clash avoidance); the
# configs (yazi's bat previewer, fzf defaults, ...) expect the upstream names.
command -v bat >/dev/null 2>&1 || ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
command -v fd >/dev/null 2>&1 || ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"

# --- tmux plugin manager -------------------------------------------------------
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "Installing tmux plugin manager (TPM)"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  log "TPM already installed — skipping"
fi

# --- git hooks -------------------------------------------------------------------
log "Enabling repo-local git hooks (.githooks)"
git config --local core.hooksPath .githooks

# --- stow ------------------------------------------------------------------------
# Same package list as setup.sh; `brew` is macOS-only so it is not stowed here.
log "Stowing dotfiles into \$HOME"
stow bat bin git mise nvim ssh tmux vim yazi zsh

# --- neovim (official tarball; apt's neovim is too old for lazy.nvim on 22.04) ---
if ! command -v nvim >/dev/null 2>&1; then
  log "Installing Neovim from GitHub releases"
  case "$arch" in
    x86_64) nvim_asset="nvim-linux-x86_64.tar.gz" ;;
    aarch64) nvim_asset="nvim-linux-arm64.tar.gz" ;;
    *)
      warn "unsupported arch for nvim: $arch — install manually"
      nvim_asset=""
      ;;
  esac
  if [[ -n "$nvim_asset" ]]; then
    curl -fsSL -o /tmp/nvim.tar.gz "https://github.com/neovim/neovim/releases/latest/download/${nvim_asset}"
    rm -rf "$HOME/.local/opt/nvim" "$HOME/.local/opt/${nvim_asset%.tar.gz}"
    tar -xzf /tmp/nvim.tar.gz -C "$HOME/.local/opt"
    mv "$HOME/.local/opt/${nvim_asset%.tar.gz}" "$HOME/.local/opt/nvim"
    ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
    rm -f /tmp/nvim.tar.gz
  fi
else
  log "nvim already installed — skipping"
fi

# --- yazi (musl binary; not in the Ubuntu archive) --------------------------------
if ! command -v yazi >/dev/null 2>&1; then
  log "Installing yazi from GitHub releases"
  case "$arch" in
    x86_64) yazi_asset="yazi-x86_64-unknown-linux-musl.zip" ;;
    aarch64) yazi_asset="yazi-aarch64-unknown-linux-musl.zip" ;;
    *)
      warn "unsupported arch for yazi: $arch — install manually"
      yazi_asset=""
      ;;
  esac
  if [[ -n "$yazi_asset" ]]; then
    curl -fsSL -o /tmp/yazi.zip "https://github.com/sxyazi/yazi/releases/latest/download/${yazi_asset}"
    rm -rf "$HOME/.local/opt/yazi" "$HOME/.local/opt/${yazi_asset%.zip}"
    unzip -qo /tmp/yazi.zip -d "$HOME/.local/opt"
    mv "$HOME/.local/opt/${yazi_asset%.zip}" "$HOME/.local/opt/yazi"
    ln -sf "$HOME/.local/opt/yazi/yazi" "$HOME/.local/bin/yazi"
    ln -sf "$HOME/.local/opt/yazi/ya" "$HOME/.local/bin/ya"
    rm -f /tmp/yazi.zip
  fi
else
  log "yazi already installed — skipping"
fi

# --- glow (yazi の Markdown previewer; not in the Ubuntu archive) ------------------
if ! command -v glow >/dev/null 2>&1; then
  log "Installing glow from GitHub releases"
  case "$arch" in
    x86_64) glow_arch="x86_64" ;;
    aarch64) glow_arch="arm64" ;;
    *) glow_arch="" ;;
  esac
  glow_url=""
  if [[ -n "$glow_arch" ]]; then
    # Asset names embed the version (glow_<ver>_Linux_<arch>.tar.gz), so resolve
    # the URL via the GitHub API instead of /releases/latest/download/.
    glow_url=$(curl -fsSL https://api.github.com/repos/charmbracelet/glow/releases/latest |
      jq -r --arg a "$glow_arch" \
        '.assets[].browser_download_url | select(test("Linux_" + $a + "\\.tar\\.gz$"))' |
      head -1) || glow_url=""
  fi
  if [[ -n "$glow_url" ]]; then
    curl -fsSL -o /tmp/glow.tar.gz "$glow_url"
    rm -rf /tmp/glow-extract && mkdir -p /tmp/glow-extract
    tar -xzf /tmp/glow.tar.gz -C /tmp/glow-extract
    find /tmp/glow-extract -type f -name glow -exec install -m 0755 {} "$HOME/.local/bin/glow" \;
    rm -rf /tmp/glow.tar.gz /tmp/glow-extract
  else
    warn "could not resolve a glow release asset — install manually (yazi's md preview needs it)"
  fi
else
  log "glow already installed — skipping"
fi

# --- fzf (GitHub release; apt's 0.44 lacks --zsh and diverges from macOS) ----------
if ! command -v fzf >/dev/null 2>&1; then
  log "Installing fzf from GitHub releases"
  case "$arch" in
    x86_64) fzf_arch="amd64" ;;
    aarch64) fzf_arch="arm64" ;;
    *) fzf_arch="" ;;
  esac
  fzf_url=""
  if [[ -n "$fzf_arch" ]]; then
    # Asset names embed the version (fzf-<ver>-linux_<arch>.tar.gz).
    fzf_url=$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest |
      jq -r --arg a "$fzf_arch" \
        '.assets[].browser_download_url | select(test("linux_" + $a + "\\.tar\\.gz$"))' |
      head -1) || fzf_url=""
  fi
  if [[ -n "$fzf_url" ]]; then
    curl -fsSL -o /tmp/fzf.tar.gz "$fzf_url"
    tar -xzf /tmp/fzf.tar.gz -C "$HOME/.local/bin" fzf
    rm -f /tmp/fzf.tar.gz
  else
    warn "could not resolve an fzf release asset — install manually"
  fi
else
  log "fzf already installed — skipping"
fi

# --- mise tools --------------------------------------------------------------
if ! command -v mise >/dev/null 2>&1; then
  log "Installing mise"
  curl -fsSL https://mise.run | sh
fi
log "Installing mise-managed tools"
mise install

# --- yazi plugins ------------------------------------------------------------
if command -v ya >/dev/null 2>&1; then
  log "Installing yazi plugins (ya pkg install)"
  ya pkg install
else
  log "ya (yazi) not found — skipping yazi plugin install"
fi

# --- uv + default Python -------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
if command -v uv >/dev/null 2>&1; then
  log "Setting uv's Python 3.14 as the default interpreter"
  uv python install 3.14 --default --preview-features python-install-default
fi

# --- login shell ---------------------------------------------------------------
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]]; then
  log "Changing login shell to zsh (chsh may ask for your password)"
  chsh -s "$(command -v zsh)" || warn "chsh failed — run manually: chsh -s \$(command -v zsh)"
fi

log "Setup complete."
cat <<'EOF'

Next steps:
  1. exec zsh   (or open a new terminal)
  2. Start tmux and press  prefix + I  to install tmux plugins.
  3. (Optional) Generate an SSH key and register it with GitHub:
       ssh-keygen -t ed25519 -C "<your-email>"
EOF
