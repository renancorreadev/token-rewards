#!/bin/bash
set -e

HOME_DIR="/home/ethsec"

###
### Powerlevel10k
###
echo "🔧 Installing Powerlevel10k..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "${ZSH_CUSTOM:-$HOME_DIR/.oh-my-zsh/custom}/themes/powerlevel10k" 2>/dev/null || true

# Set Powerlevel10k as the ZSH theme
sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$HOME_DIR/.zshrc"

# Oh My Zsh plugins
sed -i 's|^plugins=(.*)|plugins=(git docker npm node sudo zsh-autosuggestions zsh-syntax-highlighting)|' "$HOME_DIR/.zshrc"

# Install zsh-autosuggestions and zsh-syntax-highlighting
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
  "${ZSH_CUSTOM:-$HOME_DIR/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" 2>/dev/null || true
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
  "${ZSH_CUSTOM:-$HOME_DIR/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" 2>/dev/null || true

# Powerlevel10k instant prompt + minimal config for non-interactive use
cat >> "$HOME_DIR/.zshrc" << 'ZSHEOF'

# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ETH Security Toolbox paths
export PATH="${PATH}:${HOME}/.local/bin:${HOME}/.vyper/bin:${HOME}/.foundry/bin"

# Load Powerlevel10k config
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHEOF

# Write a lean p10k config
cat > "$HOME_DIR/.p10k.zsh" << 'P10KEOF'
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir vcs prompt_char
  )
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status command_execution_time background_jobs node_version
  )

  typeset -g POWERLEVEL9K_MODE=unicode
  typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false
  typeset -g POWERLEVEL9K_ICON_PADDING=none
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

  # Dir
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=3

  # VCS (git)
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=178

  # Prompt char
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196

  # Command execution time
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=101

  # Transient prompt
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir

  # Instant prompt
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
P10KEOF



###
### Verify tools
###
echo ""
echo "✅ Ethereum Security Toolbox ready"
echo "---"
solc --version
forge --version
slither --version 2>/dev/null || true
echidna --version
medusa --version
claude --version
echo "---"
echo "🐚 Shell: zsh + Oh My Zsh + Powerlevel10k"
