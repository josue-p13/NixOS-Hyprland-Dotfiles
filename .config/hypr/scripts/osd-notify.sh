#!/usr/bin/env bash

FIFO="/tmp/gruvbox_osd_fifo"

case "$1" in
    vol-up)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
        # Obtener volumen actual: "Volume: 0.50" -> 50
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100}')
        echo "vol $VOL" > "$FIFO"
        ;;
    vol-down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100}')
        echo "vol $VOL" > "$FIFO"
        ;;
    vol-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        # Si está muteado, enviamos 0, si no, el volumen actual
        IS_MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep "MUTED")
        if [ -n "$IS_MUTED" ]; then
            echo "vol 0" > "$FIFO"
        else
            VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100}')
            echo "vol $VOL" > "$FIFO"
        fi
        ;;
    bri-up)
        brightnessctl s +5%
        BRI=$(brightnessctl -m | awk -F, '{print $4}' | tr -d '%')
        echo "bri $BRI" > "$FIFO"
        ;;
    bri-down)
        brightnessctl s 5%-
        BRI=$(brightnessctl -m | awk -F, '{print $4}' | tr -d '%')
        echo "bri $BRI" > "$FIFO"
        ;;
esac
