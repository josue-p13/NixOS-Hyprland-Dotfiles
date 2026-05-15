#!/bin/bash
# Script robusto para Hot Corner y Hover de "Activities"
# Sin depender de jq si es posible, usando bash nativo para velocidad

ACTIVITIES_WIDTH=150
ACTIVITIES_HEIGHT=50

triggered=0

while true; do
    # Obtener posición cruda para evitar overhead
    pos=$(hyprctl cursorpos)
    x=$(echo "$pos" | cut -d',' -f1)
    y=$(echo "$pos" | cut -d',' -f2 | tr -d ' ')

    # Debug: uncomment to see coords in a terminal
    # echo "X: $x, Y: $y"

    if (( x <= ACTIVITIES_WIDTH )) && (( y <= ACTIVITIES_HEIGHT )); then
        if [ $triggered -eq 0 ]; then
            # Intentar el dispatch de forma limpia
            hyprctl dispatch hyprexpo:expo toggle
            triggered=1
            sleep 0.8 # Cooldown para evitar disparos accidentales
        fi
    else
        triggered=0
    fi
    sleep 0.05 # Más rápido para que sea instantáneo
done
