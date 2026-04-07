#!/bin/bash
# Oedon Backup System - Telegram Integrated
set -euo pipefail

# --- Paths & Env ---
PROJECT_DIR="$(cd "$(dirname "$(dirname "$0")")" && pwd)"
source "${PROJECT_DIR}/.env"

BACKUP_DIR="${PROJECT_DIR}/backups"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y-%m-%d_%H%M)
FILE_NAME="oedon_backup_${DATE}.tar.gz"
DEST="${BACKUP_DIR}/${FILE_NAME}"

echo "📦 Starting backup: ${FILE_NAME}..."

# 1. Dump Database (WordPress as example)
# We use 'docker exec' so we don't need mysql installed on the host
docker exec wordpress-db mysqldump -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" > "${BACKUP_DIR}/db_dump.sql"

# 2. Compress DB + Apps + Configs
# We exclude node_modules or cache folders to save space
tar -czf "$DEST" \
    -C "$PROJECT_DIR" \
    apps/ \
    config/ \
    apps.list \
    .env \
    -C "${BACKUP_DIR}" db_dump.sql

# 3. Send to Telegram using 'curl'
echo "🚀 Sending to Telegram..."
RESPONSE=$(curl -s -F chat_id="${TELEGRAM_CHAT_ID}" \
     -F document=@"${DEST}" \
     -F caption="✅ Oedon Backup - ${DATE}" \
     "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument")

# 4. Cleanup
rm "${BACKUP_DIR}/db_dump.sql"
# Optional: keep only the last 3 local backups to save disk space
ls -t "${BACKUP_DIR}"/oedon_backup_* | tail -n +4 | xargs -r rm

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✔️ Backup successfully uploaded to Telegram."
else
    echo "❌ Failed to send backup to Telegram."
    exit 1
fi
