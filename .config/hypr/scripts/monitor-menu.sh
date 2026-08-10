#!/usr/bin/env bash

INTERNAL="eDP-1"

# Detectar monitor externo conectado de forma dinámica
EXTERNAL=""
for status_file in /sys/class/drm/card*/status; do
    if [ "$(cat "$status_file" 2>/dev/null)" = "connected" ]; then
        conn_name=$(basename "$(dirname "$status_file")" | sed -E 's/card[0-9]+-//')
        if [ "$conn_name" != "$INTERNAL" ]; then
            EXTERNAL="$conn_name"
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

OPTIONS="Extender
Ampliar (Duplicar)
Solo Interna
Solo Externa"

CHOICE=$(echo -e "$OPTIONS" | wofi --dmenu -p "Pantalla")

case "$CHOICE" in
    *"Extender"*)
        hyprctl keyword monitor "$INTERNAL",preferred,0x0,1
        hyprctl keyword monitor "$EXTERNAL",preferred,1920x0,1
        ;;
    *"Ampliar (Duplicar)"*)
        hyprctl keyword monitor "$INTERNAL",preferred,auto,1
        hyprctl keyword monitor "$EXTERNAL",preferred,auto,1,mirror,"$INTERNAL"
        ;;
    *"Solo Interna"*)
        hyprctl keyword monitor "$EXTERNAL",disable
        hyprctl keyword monitor "$INTERNAL",preferred,auto,1
        ;;
    *"Solo Externa"*)
        hyprctl keyword monitor "$INTERNAL",disable
        hyprctl keyword monitor "$EXTERNAL",preferred,auto,1
        ;;
esac

