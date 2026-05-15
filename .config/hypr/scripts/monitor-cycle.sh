#!/usr/bin/env bash

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-2"

# Detectar estado actual
INT_ACTIVE=$(hyprctl monitors -j | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if m['name'] == '$INTERNAL' and not m.get('disabled', True):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null && echo 1 || echo 0)

# Detectar ruta del monitor externo dinámicamente
EXT_STATUS_FILE=$(ls /sys/class/drm/card*-HDMI-A-2/status 2>/dev/null | head -n 1)
EXT_CONNECTED=$(cat "$EXT_STATUS_FILE" 2>/dev/null)
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
