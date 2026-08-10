#!/usr/bin/env bash
# auto-gpu.sh - Versión PERSISTENTE (vía monitors.conf)

USER_NAME="josue"
USER_ID="1000"
INTERNAL="eDP-1"
STATE_FILE="/home/josue/.cache/last_hdmi_status"
MONITOR_CONF="/home/josue/.cache/hypr/monitors.conf"
LOG_FILE="/tmp/gpu_auto.log"

mkdir -p "$(dirname "$STATE_FILE")"
mkdir -p "$(dirname "$MONITOR_CONF")"

# Función para ejecutar hyprctl como usuario
hypr_cmd() {
    if pgrep -x "Hyprland" > /dev/null; then
        local sig=$(ls -1 /run/user/$USER_ID/hypr/ 2>/dev/null | head -1)
        if [ -n "$sig" ]; then
            sudo -u "$USER_NAME" XDG_RUNTIME_DIR=/run/user/$USER_ID HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl "$@" >/dev/null 2>&1
        fi
    fi
}

# Detectar monitor externo conectado de forma dinámica
EXTERNAL=""
ESTADO="disconnected"
for status_file in /sys/class/drm/card*/status; do
    if [ "$(cat "$status_file" 2>/dev/null)" = "connected" ]; then
        conn_name=$(basename "$(dirname "$status_file")" | sed -E 's/card[0-9]+-//')
        if [ "$conn_name" != "$INTERNAL" ]; then
            EXTERNAL="$conn_name"
            ESTADO="connected"
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

LAST_ESTADO=$(cat "$STATE_FILE" 2>/dev/null)

# --- FASE 1: GESTIÓN DE POTENCIA (MHz) ---
if [ "$ESTADO" == "connected" ]; then
    if [ "$EUID" -eq 0 ]; then
        nvidia-smi -rgc >/dev/null 2>&1
    else
        sudo nvidia-smi -rgc >/dev/null 2>&1
    fi
    hypr_cmd keyword cursor:no_hardware_cursors true
else
    if [ "$EUID" -eq 0 ]; then
        nvidia-smi -lgc 210,2200 >/dev/null 2>&1
    else
        sudo nvidia-smi -lgc 210,2200 >/dev/null 2>&1
    fi
    hypr_cmd keyword cursor:no_hardware_cursors false
fi

# --- FASE 2: GESTIÓN DE MONITORES ---
# Escribimos la configuración persistente en monitors.conf
# En lugar de desactivar la interna, las extendemos por defecto para evitar pantallas negras.

if [ "$ESTADO" == "connected" ]; then
    # EXTENDER (Monitor externo principal, Laptop secundaria)
    cat <<EOF > "$MONITOR_CONF"
monitor=$EXTERNAL,1920x1080@144,0x0,1
monitor=$INTERNAL,preferred,1920x0,1
EOF
    
    if [ "$ESTADO" != "$LAST_ESTADO" ]; then
        echo "$(date): [AUTO-GPU] Monitor conectado - Configurando EXTENDER" >> "$LOG_FILE"
    fi
else
    # SOLO INTERNA (Laptop activa, HDMI desactivado)
    cat <<EOF > "$MONITOR_CONF"
monitor=$EXTERNAL,disable
monitor=$INTERNAL,preferred,auto,1
EOF
    
    if [ "$ESTADO" != "$LAST_ESTADO" ]; then
        echo "$(date): [AUTO-GPU] Monitor desconectado - Configurando SOLO INTERNA" >> "$LOG_FILE"
    fi
fi

# Aplicar el cambio inmediatamente
hypr_cmd reload

# Guardar el estado
echo "$ESTADO" > "$STATE_FILE"
chmod 666 "$STATE_FILE" 2>/dev/null
chmod 666 "$MONITOR_CONF" 2>/dev/null
