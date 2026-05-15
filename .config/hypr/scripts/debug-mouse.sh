#!/usr/bin/env bash
# Script de depuración para ver coordenadas del mouse
while true; do
    pos=$(hyprctl cursorpos -j)
    echo "Posición: $pos"
    sleep 1
done
