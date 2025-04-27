# Ignore lints about referencing unknown variables and unused variables.
# shellcheck disable=SC2034 disable=SC2154

# Available themes: https://github.com/ohmyzsh/ohmyzsh/wiki/themes
ZSH_THEME="simple"

plugins=(
  command-time
  fzf
  git
  mix
  npm
  rust
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# === zsh-autosuggestions ===

# The default is just `history`. Include default completion suggestions too.
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# === fzf ===
FZF_DEFAULT_OPTS='--height 40% --layout=reverse'

# === zsh-syntax-highlighting ===
# Docs: https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md

typeset -A ZSH_HIGHLIGHT_STYLES

ZSH_HIGHLIGHT_STYLES['reserved-word']='fg=#08dc92'

ZSH_HIGHLIGHT_STYLES[assign]='fg=#9cdcfe,bold'
ZSH_HIGHLIGHT_STYLES['dollar-double-quoted-argument']='fg=#9cdcfe,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#dfff6d,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=#dfff6d,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#dfff6d,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=#dfff6d,bold'
ZSH_HIGHLIGHT_STYLES[path]="fg=#ce9178"
ZSH_HIGHLIGHT_STYLES['single-quoted-argument']='fg=#ce9178'
ZSH_HIGHLIGHT_STYLES['double-quoted-argument']='fg=#ce9178'
ZSH_HIGHLIGHT_STYLES['double-hyphen-option']='fg=#dfad40,bold'
ZSH_HIGHLIGHT_STYLES['single-hyphen-option']='fg=#dfad40,bold'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#e81e31,bold'
ZSH_HIGHLIGHT_STYLES[default]='fg=#ffffff'

### ====================

# Shellcheck can't dive into this file, that's expected.
# shellcheck disable=SC1091
. "$HOME/.oh-my-zsh/oh-my-zsh.sh"

# Based on this example:
# https://github.com/popstas/zsh-command-time#configuration
#
# This version looks a bit better because it humanizes the duration
function zsh_command_time {
  if [ -z "$ZSH_COMMAND_TIME" ]; then
    return 0
  fi

  hours=$((ZSH_COMMAND_TIME / 3600))
  min=$((ZSH_COMMAND_TIME / 60))
  sec=$((ZSH_COMMAND_TIME % 60))
  if [ "$ZSH_COMMAND_TIME" -le 60 ]; then
    timer_show="${fg[green]}${ZSH_COMMAND_TIME}s"
  elif [ "$ZSH_COMMAND_TIME" -gt 60 ] && [ "$ZSH_COMMAND_TIME" -le 180 ]; then
    timer_show="${fg[yellow]}$min min. $sec s."
  elif [ "$hours" -gt 0 ]; then
    min=$((min % 60))
    timer_show="${fg[red]}${hours}h ${min}m ${sec}s"
  else
    timer_show="${fg[red]}${min}m ${sec}s"
  fi

  echo "${fg_bold[white]}Took $timer_show$reset_color"
}
