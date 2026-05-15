#!/usr/bin/env bash

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-2"

OPTIONS="Extender
Solo Interna
Solo Externa"

CHOICE=$(echo -e "$OPTIONS" | wofi --dmenu -p "Pantalla")

case "$CHOICE" in
    *"Extender"*)
        hyprctl keyword monitor "$INTERNAL",preferred,0x0,1
        hyprctl keyword monitor "$EXTERNAL",preferred,1920x0,1
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
