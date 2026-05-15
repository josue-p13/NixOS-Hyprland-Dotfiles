#!/usr/bin/env bash

python3 /home/josue/.config/hypr/scripts/get-audio-devices.py sinks > /tmp/sinks.txt
python3 /home/josue/.config/hypr/scripts/get-audio-devices.py sources > /tmp/sources.txt

echo -e "Salida\nEntrada" > /tmp/choice.txt
wofi -d -p "Dispositivo" -i < /tmp/choice.txt > /tmp/choice_result.txt

CHOICE=$(cat /tmp/choice_result.txt)
rm -f /tmp/choice.txt /tmp/choice_result.txt

if [ -z "$CHOICE" ]; then exit 0; fi

if [[ "$CHOICE" == *"Salida"* ]]; then
    wofi -d -p "Elegir Salida" -i < /tmp/sinks.txt > /tmp/selected.txt
else
    wofi -d -p "Elegir Entrada" -i < /tmp/sources.txt > /tmp/selected.txt
fi

SELECTED=$(cat /tmp/selected.txt 2>/dev/null)
rm -f /tmp/sinks.txt /tmp/sources.txt /tmp/selected.txt

if [ -n "$SELECTED" ]; then
    ID=$(echo "$SELECTED" | awk '{print $1}' | cut -d':' -f1)
    wpctl set-default "$ID"
fi
