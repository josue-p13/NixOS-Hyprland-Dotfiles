#!/usr/bin/env bash

INTERNAL="eDP-1"

# Detectar monitor externo conectado de forma dinámica
EXTERNAL=""
EXT_CONNECTED="disconnected"
for status_file in /sys/class/drm/card*/status; do
    if [ "$(cat "$status_file" 2>/dev/null)" = "connected" ]; then
        conn_name=$(basename "$(dirname "$status_file")" | sed -E 's/card[0-9]+-//')
        if [ "$conn_name" != "$INTERNAL" ]; then
            EXTERNAL="$conn_name"
            EXT_CONNECTED="connected"
            break
        fi
    fi
done

if [ -z "$EXTERNAL" ]; then
    # Buscar algún puerto HDMI físico disponible como fallback
    HDMI_PORT=$(ls /sys/class/drm/card*-HDMI-A-*/status 2>/dev/null | head -1)
    if [ -n "$HDMI_PORT" ]; then
        EXTERNAL=$(basename "$(dirname "$HDMI_PORT")" | sed -E 's/card[0-9]+-//')
    else
        EXTERNAL="HDMI-A-2" # fallback absoluto
    fi
fi

# Detectar estado actual de la pantalla interna
INT_ACTIVE=$(hyprctl monitors -j | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if m['name'] == '$INTERNAL' and not m.get('disabled', True):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null && echo 1 || echo 0)

# Detectar si el monitor externo está activo en Hyprland
EXT_ACTIVE=$(hyprctl monitors -j | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if m['name'] == '$EXTERNAL' and not m.get('disabled', True):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null && echo 1 || echo 0)

# Lógica de ciclo
if [ "$EXT_CONNECTED" != "connected" ]; then
    # Sin monitor externo: solo activar interna
    hyprctl keyword monitor "$INTERNAL",preferred,auto,1
    notify-send "Pantalla" "Solo Interna (no hay monitor externo)" -i video-display -t 2000
elif [ "$INT_ACTIVE" = "1" ] && [ "$EXT_ACTIVE" = "1" ]; then
    # Extender → Solo Interna
    hyprctl keyword monitor "$EXTERNAL",disable
    hyprctl keyword monitor "$INTERNAL",preferred,auto,1
    notify-send "Pantalla" "Solo Interna" -i video-display -t 2000
elif [ "$INT_ACTIVE" = "1" ] && [ "$EXT_ACTIVE" = "0" ]; then
    # Solo Interna → Solo Externa
    hyprctl keyword monitor "$INTERNAL",disable
    hyprctl keyword monitor "$EXTERNAL",preferred,auto,1
    notify-send "Pantalla" "Solo Externa" -i video-display -t 2000
elif [ "$INT_ACTIVE" = "0" ] && [ "$EXT_ACTIVE" = "1" ]; then
    # Solo Externa → Extender
    hyprctl keyword monitor "$INTERNAL",preferred,0x0,1
    hyprctl keyword monitor "$EXTERNAL",preferred,1920x0,1
    notify-send "Pantalla" "Extender" -i video-display -t 2000
else
    # Fallback: Extender
    hyprctl keyword monitor "$INTERNAL",preferred,0x0,1
    hyprctl keyword monitor "$EXTERNAL",preferred,1920x0,1
    notify-send "Pantalla" "Extender (fallback)" -i video-display -t 2000
fi
