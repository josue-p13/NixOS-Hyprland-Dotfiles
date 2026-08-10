# --- OH MY ZSH CONFIG ---
export ZSH="$HOME/.oh-my-zsh"

# Tema: Desactivado para usar Starship
ZSH_THEME=""

# Plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  z
)

source $ZSH/oh-my-zsh.sh

# --- ALIASES (Copiados de tu Bash) ---
alias nix-apply="pushd /etc/nixos && sudo git add . && sudo nixos-rebuild switch --flake .#nixos && popd"
alias nix-edit="sudo nvim /etc/nixos/configuration.nix"
alias nix-clean="sudo nix-collect-garbage -d"

# PATH adicional
export PATH="$HOME/.bun/bin:$HOME/.npm-global/bin:$PATH"

# Starship init (NixOS normally handles this if enabled in programs.starship, 
# but we ensure it's here if not automatically injected)
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
eval "$(starship init zsh)"

alias zed="zeditor"
alias zen="zen-beta"
alias init-cuda="/home/josue/scripts/init-cuda.sh"

# Eza aliases
alias ls="eza --icons"
alias ll="eza -lh --icons --grid"
alias la="eza -a --icons"
alias lt="eza --tree --icons"


# Added by Antigravity CLI installer
export PATH="/home/josue/.local/bin/antigravity-test:$PATH"


# Added by Antigravity CLI installer
export PATH="/home/josue/.local/bin:$PATH"

# Editor por defecto
export EDITOR="nvim"
export VISUAL="nvim"

