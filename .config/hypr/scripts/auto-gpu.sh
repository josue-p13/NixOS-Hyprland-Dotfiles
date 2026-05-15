#!/usr/bin/env bash
sleep 1

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-2"

# Encontrar el conector HDMI de NVIDIA dinámicamente (el orden de cardX cambia entre boots)
NVIDIA_HDMI=$(ls /sys/class/drm/card*-HDMI-A-2/status 2>/dev/null | head -1)

if [ -z "$NVIDIA_HDMI" ]; then
    echo "$(date): No se encontró HDMI-A-2" >> /tmp/gpu_auto.log
    exit 0
fi

ESTADO=$(cat "$NVIDIA_HDMI")

if [ "$ESTADO" == "connected" ]; then
    # MODO MONITOR EXTERNO
    nvidia-smi -rgc
    hyprctl keyword cursor:no_hardware_cursors true
    # Activar ambos monitores (extender)
    hyprctl keyword monitor "$INTERNAL",preferred,0x0,1
    hyprctl keyword monitor "$EXTERNAL",preferred,1920x0,1
    echo "$(date): Monitor conectado - Potencia liberada - Cursor software - Extender" >> /tmp/gpu_auto.log
else
    # MODO LAPTOP
    nvidia-smi -lgc 210,2200
    hyprctl keyword cursor:no_hardware_cursors false
    # Desactivar externo, solo interno
    hyprctl keyword monitor "$EXTERNAL",disable
    hyprctl keyword monitor "$INTERNAL",preferred,auto,1
    echo "$(date): Monitor desconectado - Límite aplicado (2200MHz) - Cursor hardware - Solo interna" >> /tmp/gpu_auto.log
fi
