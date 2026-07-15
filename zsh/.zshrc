# language setting
export LANG=ja_JP.UTF-8
export LESSCHARSET=utf-8
export LC_ALL=ja_JP.UTF-8

# OS detection — this file is shared between macOS and Ubuntu (incl. WSL)
[[ "$OSTYPE" == darwin* ]] && IS_MAC=1 || IS_MAC=

# emacs keybind
bindkey -e

# history
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000
setopt share_history hist_ignore_all_dups hist_reduce_blanks extended_history

# use colors
autoload -Uz colors ; colors
autoload -Uz compinit && compinit

# vcs_info (git branch in prompt)
autoload -Uz vcs_info
precmd_functions+=( vcs_info )
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' (%b)'
setopt prompt_subst

# set nvim as the default editor (vim kept as a fallback)
export EDITOR="nvim"

# disable flow control
setopt no_flow_control

# enable wild card extension
setopt extended_glob

# auto complete
setopt auto_param_keys
# zsh plugins — Homebrew (macOS) or apt (Ubuntu) install locations
for _p in /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
          /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [ -f "$_p" ] && source "$_p" && break
done
for _p in /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
          /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  [ -f "$_p" ] && source "$_p" && break
done
unset _p
setopt mark_dirs
export LSCOLORS=Exfxcxdxbxegedabagacad
export LS_COLORS='di=01;34:ln=01;35:so=01;32:ex=01;31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion::complete:*' use-cache true
zstyle ':completion:*' list-colors "${LS_COLORS}"

# alias
alias vz='nvim ~/.zshrc'
alias sz='source ~/.zshrc'
alias ll='ls -al'
alias bcat='bat'
alias here='pwd | clip-copy' # clip-copy: bin パッケージの可搬クリップボード
if [[ -n $IS_MAC ]]; then
  alias ls='ls -G'
  alias o='open .'
  alias nq='networkQuality'
  alias bs='brew search'
  alias bi='brew info'
  alias brltst='brew update && brew upgrade && brew cleanup && brew doctor && mas update'
  alias brcl='brew cleanup --prune=all'
  alias brewdump='brew bundle dump --global --force --no-vscode --no-npm'
elif grep -qi microsoft /proc/version 2>/dev/null; then
  alias ls='ls --color=auto'
  alias o='explorer.exe .' # WSL: カレントを Windows エクスプローラで開く
else
  alias ls='ls --color=auto'
  alias o='xdg-open .'
fi
alias tmuxsource='tmux source ~/.tmux.conf 2>&1'  
alias lg='lazygit'

# prompt setting
PROMPT=' %B%F{blue}%~%f%b%F{yellow}${vcs_info_msg_0_}%f'$'\n''%B%(?,%F{green},%F{red})%(!,#,>)%f%b '

# PATH setting
typeset -U path PATH
if [[ -n $IS_MAC ]]; then
  export PATH="/opt/homebrew/opt/git:$PATH"
  export PATH="/opt/homebrew/opt/php:$PATH"
  export PATH="/opt/homebrew/opt/curl/bin:$PATH"
  export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
  export PATH="/Library/TeX/texbin:$PATH"

  # for compilers to find curl
  export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/curl/include"

  # forpkgconf to find curl
  export PKG_CONFIG_PATH="/opt/homebrew/opt/curl/lib/pkgconfig"
fi
export PATH="$HOME/.local/bin:$PATH"


# Pandoc
alias html2md='pandoc -f html-native_divs-native_spans -t markdown_strict --wrap=none --strip-comments'
alias html2gfm='pandoc -f html-native_divs-native_spans -t gfm --wrap=none --strip-comments'
md2pdf() { pandoc "$1" -o "${1%.md}.pdf" --pdf-engine=lualatex -V documentclass=ltjsarticle; }
docx2md() { pandoc -s "$1" --wrap=none --extract-media=media -t gfm -o "${1%.docx}.md"; }

# fzf (Ctrl-R: 履歴検索, Ctrl-T: ファイル検索, Alt-C: ディレクトリ移動)
if command -v fzf &>/dev/null; then
  _fzf_init="$(fzf --zsh 2>/dev/null)"
  if [ -n "$_fzf_init" ]; then
    eval "$_fzf_init"
  else
    # fzf < 0.48 (Ubuntu apt 版) には --zsh が無いので同梱スクリプトを読む
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
  unset _fzf_init
fi
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# mise (Node/Python/etc version manager)
command -v mise &>/dev/null && eval "$(mise activate zsh)"

# uv auto complete
command -v uv &>/dev/null && eval "$(uv generate-shell-completion zsh)"

# Refresh VS Code env vars from tmux so Claude Code's IDE integration
# tracks the current VS Code window's SSE port across reattaches.
claude() {
  if [[ -n "$TMUX" ]]; then
    eval "$(tmux show-environment -s 2>/dev/null)"
    # Force the real in-tmux TERM. Panes/sessions created before the
    # update-environment fix (and reattaches on a long-lived server, since the
    # `-a` appended TERM lingers) carry the client's xterm-256color. With
    # TERM=xterm-* under tmux, `claude` sees an inconsistent setup and refuses
    # fullscreen (/tui) rendering. default-terminal is tmux-256color.
    local _dt="$(tmux show-options -gv default-terminal 2>/dev/null)"
    export TERM="${_dt:-tmux-256color}"
  fi
  command claude "$@"
}

# tmux auto-start.
# Skip while Claude Desktop is resolving the shell environment: it launches an
# interactive login shell to capture env vars, and without this guard that shell
# auto-attaches tmux, leaking CLAUDE_DESKTOP_RESOLVING_ENVIRONMENT into the tmux
# server's global env. That then propagates to every pane and makes the claude
# CLI treat itself as embedded and refuse fullscreen (/tui) rendering.
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ -z "$CLAUDE_DESKTOP_RESOLVING_ENVIRONMENT" ]] && command -v tmux &>/dev/null; then
  tmux attach || tmux new
fi

# Yazi recommended shell Wrapper
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}
