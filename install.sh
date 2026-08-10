#!/usr/bin/env bash

# --- JOSUE'S DOTFILES INSTALLER FOR NIXOS ---
# Este script crea los enlaces simbólicos necesarios para que NixOS
# reconozca tus dotfiles sin necesidad de Home Manager.

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

echo "🚀 Iniciando la instalación de los Dotfiles de Josué..."

# Crear carpeta .config si no existe
mkdir -p "$CONFIG_DIR"

# Función para crear enlaces simbólicos de forma segura
link_file() {
    local src=$1
    local dest=$2
    
    if [ -L "$dest" ]; then
        echo "🔗 El enlace para $(basename "$dest") ya existe. Saltando..."
    elif [ -e "$dest" ]; then
        local backup="${dest}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "⚠️  $(basename "$dest") ya existe. Haciendo backup en $backup..."
        mv "$dest" "$backup"
        ln -s "$src" "$dest"
        echo "✅ Enlazado: $(basename "$dest")"
    else
        ln -s "$src" "$dest"
        echo "✅ Enlazado: $(basename "$dest")"
    fi
}

# --- ENLAZAR CARPETAS DE CONFIGURACIÓN ---
echo "📂 Enlazando aplicaciones en .config..."
for app in hypr waybar swaync wofi nwg-drawer ghostty gtk-3.0 gtk-4.0 wallust yazi zed; do
    if [ -d "$DOTFILES_DIR/.config/$app" ]; then
        link_file "$DOTFILES_DIR/.config/$app" "$CONFIG_DIR/$app"
    fi
done

# --- ENLAZAR ARCHIVOS DE SHELL ---
echo "🐚 Enlazando archivos de la Shell..."
link_file "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

echo ""
echo "✨ ¡Instalación completada con éxito!"
echo "💡 Recuerda que para que todo funcione, debes tener instalados los paquetes correspondientes en tu /etc/nixos/configuration.nix"
echo "🎨 Disfruta de tu setup Gruvbox."
