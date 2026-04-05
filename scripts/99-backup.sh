#!/bin/bash
# ./scripts/99-backup.sh - generic backup for nebula

# automatically detect route
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_DIR="${SCRIPT_DIR}"
BACKUP_PATH="${BASE_DIR}/backups/$(date +%Y%m%d_%H%M%S)"


mkdir -p "$BACKUP_PATH"

echo "--- Initiating NEBULA backup---"
echo "base directory: $BASE_DIR"
echo "backup path: $BACKUP_PATH"

# 1. System configuration (UFW y SSH)
echo "[1/3] backing up access and network configurations..."
sudo tar -czf "$BACKUP_PATH/system_config.tar.gz" /etc/ssh /etc/fail2ban /etc/ufw 2>/dev/null

# 2. Docker data (NPM, Bases de datos, WordPress)
echo "[2/3] Compressing Docker volumes..."
tar -czf "$BACKUP_PATH/docker_data.tar.gz" -C "$BASE_DIR" data/

# 3. Adjusting permissions (so u can manage the backup)
sudo chown -R $USER:$USER "$BACKUP_PATH"

# OPTIONAL: deletes backups that are older than 7 days to save disk space
find "$BASE_DIR/backups/" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null

echo "--- Backup completado con éxito en $BACKUP_PATH ---"
