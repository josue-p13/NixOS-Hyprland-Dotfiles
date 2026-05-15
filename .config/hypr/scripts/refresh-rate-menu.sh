#!/usr/bin/env bash

# Obtener monitor enfocado
MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
# Si no hay uno enfocado explícitamente, usar el primero
if [ -z "$MONITOR" ]; then
    MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')
fi

# Extraer los modos disponibles para el monitor específico
# Usamos un pequeño bloque de awk para capturar solo la línea availableModes del monitor correcto
MODES=$(hyprctl monitors all | awk "/Monitor $MONITOR/{found=1} /availableModes/ && found{print \$0; found=0}" | sed 's/.*availableModes: //')

# Si por alguna razón MODES está vacío, intentar buscar de forma más agresiva
if [ -z "$MODES" ]; then
    MODES=$(hyprctl monitors all | grep -A 25 "Monitor $MONITOR" | grep "availableModes" | head -n 1 | sed 's/.*availableModes: //')
fi

# Formatear opciones para wofi (una por línea)
OPTIONS=$(echo "$MODES" | tr ' ' '\n' | sort -rn | uniq)

# Si no hay opciones, salir
if [ -z "$OPTIONS" ]; then
    notify-send "Error" "No se pudieron detectar modos para $MONITOR"
    exit 1
fi

# Mostrar menú
CHOICE=$(echo -e "$OPTIONS" | wofi --dmenu --prompt "Hz para $MONITOR" --width 350 --height 300 --cache-file /dev/null)

if [ -n "$CHOICE" ]; then
    # Limpiar el "Hz" si existe para evitar problemas con hyprctl
    CHOICE_CLEAN=$(echo "$CHOICE" | sed 's/Hz//')
    
    # Obtener configuración actual para no perder posición/escala
    # Usamos awk para ser más precisos con hyprctl monitors (no todos los campos están en el JSON de igual forma)
    POS=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$MONITOR\") | (.x|tostring) + \"x\" + (.y|tostring)")
    SCALE=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$MONITOR\") | .scale")
    
    # Aplicar el cambio
    hyprctl keyword monitor "$MONITOR","$CHOICE_CLEAN","$POS","$SCALE"
    notify-send "Pantalla" "Configuración cambiada a $CHOICE_CLEAN en $MONITOR" -i display
fi
