#!/usr/bin/env bash

WALLPAPER_DIR="/home/josue/Pictures/Wallpapers"
STATE_FILE="/tmp/current_wallpaper_index"
SWAYBG="/nix/store/lfzixjiiirjinvdxhi7kch3fg4fgh2m6-swaybg-1.2.2/bin/swaybg"

# Obtener lista de wallpapers
WALLPAPERS=($(ls "$WALLPAPER_DIR" | grep -E "\.(jpg|jpeg|png)$"))

if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "Wallpaper Cycle" "No hay imágenes en $WALLPAPER_DIR"
    exit 1
fi

# Obtener índice actual
if [ -f "$STATE_FILE" ]; then
    INDEX=$(cat "$STATE_FILE")
else
    INDEX=0
fi

# Incrementar índice
NEXT_INDEX=$(( (INDEX + 1) % ${#WALLPAPERS[@]} ))
echo "$NEXT_INDEX" > "$STATE_FILE"

NEXT_WALLPAPER="$WALLPAPER_DIR/${WALLPAPERS[$NEXT_INDEX]}"

# Cambiar el fondo
# Guardamos el PID del nuevo swaybg
$SWAYBG -i "$NEXT_WALLPAPER" -m fill &
NEW_PID=$!

# Esperamos un poco para que el nuevo se muestre
sleep 0.5

# Matamos todos los swaybg EXCEPTO el que acabamos de lanzar
# Esto evita que los widgets (que ahora están en la capa BOTTOM) sean cubiertos 
# y asegura que siempre haya un wallpaper visible.
pgrep swaybg | grep -v "$NEW_PID" | xargs -r kill

notify-send "Wallpaper" "Cambiado a: ${WALLPAPERS[$NEXT_INDEX]}"
