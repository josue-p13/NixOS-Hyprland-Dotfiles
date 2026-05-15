#!/usr/bin/env bash

# Directorio de destino
BACKUP_DIR="$HOME/backups/hyprland"
mkdir -p "$BACKUP_DIR"

# Fecha para el nombre del archivo
DATE=$(date +%Y-%m-%d_%H-%M-%S)
FILE_NAME="hyprland_backup_$DATE.tar.gz"

# Directorios a respaldar
CONFIG_DIRS=(
    "$HOME/.config/hypr"
    "$HOME/.config/waybar"
    "$HOME/.config/swaync"
    "$HOME/.config/wofi"
)

# Crear el backup
echo "Iniciando backup en $BACKUP_DIR/$FILE_NAME..."
tar -czf "$BACKUP_DIR/$FILE_NAME" "${CONFIG_DIRS[@]}" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Backup completado con éxito."
    # Mantener solo los últimos 7 días de backups
    find "$BACKUP_DIR" -name "hyprland_backup_*.tar.gz" -mtime +7 -delete
    notify-send "Backup Hyprland" "Copia de seguridad diaria realizada con éxito." -i drive-harddisk
else
    echo "Error al crear el backup."
    notify-send "Backup Hyprland" "ERROR al realizar la copia de seguridad." -u critical -i dialog-error
fi
