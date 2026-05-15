#!/usr/bin/env bash
# Detecta Intel y NVIDIA dinámicamente y exporta AQ_DRM_DEVICES

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
else
    export AQ_DRM_DEVICES=""
fi
