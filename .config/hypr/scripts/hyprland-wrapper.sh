#!/usr/bin/env bash
# Wrapper para Hyprland que detecta GPUs correctas en cada boot

INTEL=""
NVIDIA=""

for card in /sys/class/drm/card[0-9]*; do
    name=$(basename "$card")
    [[ "$name" =~ - ]] && continue
    vendor=$(cat "$card/device/vendor" 2>/dev/null)
    if [ "$vendor" = "0x8086" ]; then
        INTEL="$name"
    elif [ "$vendor" = "0x10de" ]; then
        NVIDIA="$name"
    fi
done

if [ -n "$INTEL" ] && [ -n "$NVIDIA" ]; then
    export AQ_DRM_DEVICES="/dev/dri/$INTEL:/dev/dri/$NVIDIA"
fi

exec Hyprland "$@"
