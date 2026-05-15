# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- OH MY ZSH CONFIG ---
export ZSH="$HOME/.oh-my-zsh"

# Tema: Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# --- ALIASES (Copiados de tu Bash) ---
alias nix-apply="pushd /etc/nixos && sudo git add . && sudo nixos-rebuild switch --flake .#nixos && popd"
alias nix-edit="sudo nvim /etc/nixos/configuration.nix"
alias nix-clean="sudo nix-collect-garbage -d"

# PATH adicional
export PATH="$HOME/.bun/bin:$HOME/.npm-global/bin:$PATH"

# Para que Powerlevel10k no pida configuración si ya existe
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
alias zed="zeditor"
alias zen="zen-beta"
alias init-cuda='/home/josue/scripts/init-cuda.sh'
