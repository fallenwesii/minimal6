# ----------- Basics -----------
export EDITOR=vim
export VISUAL=vim


# ----------- History -----------
HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# ----------- Prompt (archlinux ~ %) -----------
PS1='\h \w % '

# ----------- Aliases (minimal + useful) -----------
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

alias grep='grep --color=auto'

# Arch shortcuts
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias cls='clear'
alias e='$EDITOR'

# ----------- Case-insensitive autocomplete -----------
# This makes tab completion ignore case (Downloads vs downloads)
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous on"

# Also helps with cd specifically
shopt -s nocaseglob

# ----------- Better CLI editing (open in vim) -----------
# Press Ctrl + x, Ctrl + e to open current command in vim
bind '"\C-x\C-e": edit-and-execute-command'


# ----------- Performance tweaks -----------
shopt -s autocd
shopt -s globstar

# ----------- PATH -----------
export PATH="$HOME/.local/bin:$PATH"

# ----------- Optional (if present) -----------
[ -f ~/.fzf.bash ] && source ~/.fzf.bash


##remove these if you don't use them
alias emacs='emacs -nw'   
alias clock='tty-clock -b -c'
alias n='nvim'
