#!/usr/bin/env bash

# Obtener información de la ventana activa en JSON
window_info=$(hyprctl activewindow -j)

# Leer el estado de flotado y pantalla completa
floating=$(echo "$window_info" | jq -r '.floating')
fullscreen=$(echo "$window_info" | jq -r '.fullscreen')

if [ "$floating" = "true" ]; then
    # Si ya está flotando, volver al modo mosaico
    hyprctl dispatch togglefloating
    notify-send "Modo Mosaico" "Ventana fijada a la rejilla" -i window-restore -t 1500
else
    # Si está en mosaico o pantalla completa
    if [ "$fullscreen" -ne 0 ]; then
        hyprctl dispatch fullscreen 0
    fi
    
    # Activar el modo flotante
    hyprctl dispatch togglefloating
    
    # Redimensionar a un tamaño estándar (1000x700) para evitar que ocupe toda la pantalla
    hyprctl dispatch resizeactive exact 1000 700
    
    # Centrar la ventana en la pantalla
    hyprctl dispatch centerwindow
    
    # Notificación de Modo Libre activado
    notify-send "Modo Libre" "Ventana flotante activada" -i window-new -t 1500
fi
