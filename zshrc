autoload colors zsh/terminfo
colors

precmd() { print "" }
PS1="⟩"
RPS1="%{$fg[magenta]%}%20<...<%~%<<%{$reset_color%}"

if [ "$TMUX" = "" ]; then tmux; fi
