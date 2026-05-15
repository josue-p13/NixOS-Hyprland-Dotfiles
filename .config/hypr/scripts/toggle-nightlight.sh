#!/usr/bin/env bash
# Script para alternar el modo noche (gammastep) - Versión Final Pro

STATE_FILE="/tmp/nightlight_active"
LOG_FILE="/tmp/nightlight.log"

# Intentar detectar el display de Wayland si no está puesto
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/1000}

if [ -f "$STATE_FILE" ]; then
    echo "$(date): Desactivando..." > "$LOG_FILE"
    rm "$STATE_FILE"
    pkill -9 gammastep
    # Reset
    gammastep -m wayland -x >> "$LOG_FILE" 2>&1 &
    disown
    notify-send "Modo Noche" "Desactivado" -i display-brightness-symbolic
else
    echo "$(date): Activando..." > "$LOG_FILE"
    touch "$STATE_FILE"
    pkill -9 gammastep
    sleep 0.2
    # El comando que sabemos que funciona, con redirección completa
    gammastep -m wayland -O 3500 >> "$LOG_FILE" 2>&1 &
    disown
    notify-send "Modo Noche" "Activado (3500K)" -i display-brightness-low-symbolic
fi
