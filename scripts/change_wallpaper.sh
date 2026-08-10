#!/usr/bin/env bash

# --- SCRIPT DE CAMBIO DE WALLPAPER DINÁMICO (WALLUST) ---

if [[ -z "$1" ]]; then
    echo "Error: Debes proporcionar la ruta de una imagen."
    echo "Uso: $0 ~/Pictures/Wallpapers/imagen.jpg"
    exit 1
fi

WALLPAPER="$1"
echo "$WALLPAPER" > ~/.cache/current_wallpaper

if [[ ! -f "$WALLPAPER" ]]; then
    echo "Error: El archivo $WALLPAPER no existe."
    exit 1
fi

echo "🖼️  Cambiando fondo a: $(basename "$WALLPAPER")..."

# 0. Asegurar que el daemon de awww esté corriendo
if ! pgrep -x "awww-daemon" > /dev/null; then
    echo "Starting awww-daemon..."
    awww-daemon &
    sleep 1
fi

# 1. Cambiar el fondo con awww (transición tipo GNOME/Overshot)
awww img "$WALLPAPER" \
    --transition-type grow \
    --transition-pos 0.85,0.85 \
    --transition-step 90 \
    --transition-fps 60

# 2. Generar nueva paleta de colores con wallust
echo "🎨 Generando paleta de colores..."
wallust run "$WALLPAPER"

# 3. Recargar Waybar para aplicar el nuevo style.css
echo "♻️  Recargando componentes..."
pkill -USR2 waybar || (waybar &)

# 4. Recargar SwayNC para aplicar colores
swaync-client -rs

# 5. Reiniciar widgets de Python y Lanzador para que lean el nuevo colors.json/css
# Los reiniciamos porque es la única forma de que cambien de color actualmente
pkill -f nwg-drawer; (GTK_THEME=Adwaita:dark nwg-drawer -r -wm hyprland -s /home/josue/.config/nwg-drawer/drawer.css > /dev/null 2>&1 &)
pkill -f gruvbox-osd.py; (hypr-python ~/.config/hypr/scripts/gruvbox-osd.py > /dev/null 2>&1 &)
pkill -f gruvbox-dock.py; (hypr-python ~/.config/hypr/scripts/gruvbox-dock.py > /dev/null 2>&1 &)

# 6. Actualizar bordes de Hyprland quirúrgicamente (evita reset de monitores)
echo "🖌️  Actualizando bordes de Hyprland..."
C5=$(grep "\$color5" ~/.cache/wallust/colors-hyprland.conf | cut -d'=' -f2 | xargs)
C12=$(grep "\$color12" ~/.cache/wallust/colors-hyprland.conf | cut -d'=' -f2 | xargs)
C8=$(grep "\$color8" ~/.cache/wallust/colors-hyprland.conf | cut -d'=' -f2 | xargs)

hyprctl keyword general:col.active_border "$C5 $C12 45deg"
hyprctl keyword general:col.inactive_border "$C8"

# 7. Actualizar fondo de SDDM (borroso)
echo "🖼️  Actualizando fondo de SDDM..."
if command -v magick > /dev/null; then
    # Crear versión borrosa (resize para velocidad, blur para estética)
    magick "$WALLPAPER" -resize 1920x1080^ -gravity center -extent 1920x1080 -blur 0x50 /tmp/sddm-background.png
    sudo cp /tmp/sddm-background.png /var/lib/sddm/background.png
    sudo chmod 644 /var/lib/sddm/background.png
    echo "✅ Fondo de SDDM actualizado."
else
    echo "⚠️  ImageMagick no encontrado, saltando actualización de SDDM."
fi

echo "✅ ¡Todo listo! Tu sistema ahora luce los colores de $(basename "$WALLPAPER")."
