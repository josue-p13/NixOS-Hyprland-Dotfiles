#!/usr/bin/env bash

# Obtener el perfil actual
CURRENT=$(powerprofilesctl get)

if [ "$CURRENT" == "power-saver" ]; then
    powerprofilesctl set balanced
    notify-send "Perfil de Energía" "Cambiado a Modo Equilibrado" -i power-profile-balanced-symbolic
else
    powerprofilesctl set power-saver
    notify-send "Perfil de Energía" "Cambiado a Modo Ahorro" -i power-profile-power-saver-symbolic
fi
