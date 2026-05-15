#!/usr/bin/env bash

# Estilo wofi (puedes reutilizar el de tus wallpapers o el general)
WOFI_STYLE="/home/josue/.config/hypr/scripts/wallpaper-selector.css"

case "$1" in
    list)
        # Mostrar historial y copiar al portapapeles
        cliphist list | wofi --show dmenu --prompt "Historial de portapapeles" --width 800 --height 500 --style "$WOFI_STYLE" --cache-file /dev/null | cliphist decode | wl-copy
        ;;
    del)
        # Borrar un elemento específico
        cliphist list | wofi --show dmenu --prompt "Borrar del historial" --width 800 --height 500 --style "$WOFI_STYLE" --cache-file /dev/null | cliphist delete
        ;;
    wipe)
        # Limpiar todo
        if [ "$(echo -e "No\nSi" | wofi --show dmenu --prompt "¿Limpiar todo el historial?" --width 300 --height 200)" == "Si" ]; then
            cliphist wipe
        fi
        ;;
esac
