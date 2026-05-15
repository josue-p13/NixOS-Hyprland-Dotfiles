#!/usr/bin/env bash

# Configuración
WALLPAPER_DIR="/home/josue/Pictures/Wallpapers"
THUMB_DIR="/home/josue/.cache/wallpaper_thumbnails"
SWAYBG="/nix/store/lfzixjiiirjinvdxhi7kch3fg4fgh2m6-swaybg-1.2.2/bin/swaybg"
MAGICK="/nix/store/pjcg9z9zj4hqa7y8jjgsx06rc31q6r8s-imagemagick-7.1.2-19/bin/magick"
WOFI_STYLE="/home/josue/.config/hypr/scripts/wallpaper-selector.css"

mkdir -p "$THUMB_DIR"

# Generar miniaturas si no existen (Calidad alta para el carrusel)
for img in "$WALLPAPER_DIR"/*.{jpg,jpeg,png,webp}; do
    [ -e "$img" ] || continue
    filename=$(basename "$img")
    thumb="$THUMB_DIR/$filename"
    if [ ! -f "$thumb" ] || [ "$img" -nt "$thumb" ]; then
        # Tamaño mayor para que se vea mejor en el carrusel
        "$MAGICK" "$img" -thumbnail 400x225 "$thumb"
    fi
done

# Crear lista para wofi
entries=""
while IFS= read -r img; do
    filename=$(basename "$img")
    thumb="$THUMB_DIR/$filename"
    # Formato para que wofi lo muestre bien en columnas
    entries+="$filename\x00img:$thumb\n"
done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f -regex ".*\(jpg\|jpeg\|png\|webp\)")

# Mostrar wofi estilo carrusel/grid
# --columns 2 o 3 crea el efecto de galería
selected=$(echo -ne "$entries" | wofi --show dmenu \
    --allow-images \
    --prompt "Galería de Wallpapers" \
    --width 900 \
    --height 700 \
    --columns 2 \
    --style "$WOFI_STYLE" \
    --cache-file /dev/null \
    --hide-scroll)

if [ -n "$selected" ]; then
    WALLPAPER="$WALLPAPER_DIR/$selected"
    
    if [ -f "$WALLPAPER" ]; then
        $SWAYBG -i "$WALLPAPER" -m fill &
        NEW_PID=$!
        sleep 0.5
        pgrep swaybg | grep -v "$NEW_PID" | xargs -r kill
        notify-send "Wallpaper" "Cambiado a: $selected"
    else
        # Limpieza de emergencia por si dmenu devuelve algo extra
        clean_name=$(echo "$selected" | sed 's/.*\x00//; s/^img://')
        WALLPAPER_ALT="$WALLPAPER_DIR/$clean_name"
        if [ -f "$WALLPAPER_ALT" ]; then
             $SWAYBG -i "$WALLPAPER_ALT" -m fill &
             NEW_PID=$!
             sleep 0.5
             pgrep swaybg | grep -v "$NEW_PID" | xargs -r kill
             notify-send "Wallpaper" "Cambiado a: $clean_name"
        fi
    fi
fi
