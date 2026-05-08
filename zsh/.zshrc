# language setting
export LANG=ja_JP.UTF-8
export LESSCHARSET=utf-8
export LC_ALL=ja_JP.UTF-8

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

# set vim for the editor
export EDITOR=vim

# disable flow control
setopt no_flow_control

# enable wild card extension
setopt extended_glob

# auto complete
setopt auto_param_keys
[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
setopt mark_dirs
export LSCOLORS=Exfxcxdxbxegedabagacad
export LS_COLORS='di=01;34:ln=01;35:so=01;32:ex=01;31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30'
zstyle ':completion::complete:*' use-cache true
zstyle ':completion:*' list-colors "${LS_COLORS}"

# alias
alias vz='vim ~/.zshrc'
alias sz='source ~/.zshrc'
alias ls='ls -G'
alias nq='networkQuality'
alias ll='ls -al'
alias bs='brew search'
alias bi='brew info'
alias bcat='bat'
alias brltst='brew update && brew upgrade && brew cleanup && brew doctor && mas update'
alias brcl='brew cleanup --prune=all'
alias o='open .'
alias here='pwd | pbcopy'

# prompt setting
PROMPT=' %B%F{blue}%~%f%b%F{yellow}${vcs_info_msg_0_}%f'$'\n''%B%(?,%F{green},%F{red})%(!,#,>)%f%b '

# PATH setting
typeset -U path PATH
export PATH="/opt/homebrew/opt/git:$PATH"
export PATH="/opt/homebrew/opt/php:$PATH"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export PATH="/Library/TeX/texbin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Pandoc
alias html2md='pandoc -f html-native_divs-native_spans -t markdown_strict --wrap=none --strip-comments'
alias html2gfm='pandoc -f html-native_divs-native_spans -t gfm --wrap=none --strip-comments'
md2pdf() { pandoc "$1" -o "${1%.md}.pdf" --pdf-engine=lualatex -V documentclass=ltjsarticle; }
docx2md() { pandoc -s "$1" --wrap=none --extract-media=media -t gfm -o "${1%.docx}.md"; }

# fzf (Ctrl-R: 履歴検索, Ctrl-T: ファイル検索, Alt-C: ディレクトリ移動)
command -v fzf &>/dev/null && eval "$(fzf --zsh)"
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# uv auto complete
eval "$(uv generate-shell-completion zsh)"

# tmux auto-start
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && command -v tmux &>/dev/null; then
  tmux attach || tmux new
fi
