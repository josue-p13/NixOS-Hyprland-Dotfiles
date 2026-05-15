#!/usr/bin/env bash

opciones="Apagar
Reiniciar
Hibernar
Suspender
Cerrar Sesion"

seleccion=$(echo -e "$opciones" | wofi -d -p "Power" 2>/dev/null)

case "$seleccion" in
    Apagar)
        systemctl poweroff
        ;;
    Reiniciar)
        systemctl reboot
        ;;
    Hibernar)
        systemctl hibernate
        ;;
    Suspender)
        systemctl suspend
        ;;
    "Cerrar Sesion")
        hyprctl dispatch exit
        ;;
esac
