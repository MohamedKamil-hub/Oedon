#!/bin/bash
# OEDON Janitor - Automated Maintenance with Emergency Mode
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
THRESHOLD=90
AGGRESSIVE=false
FORCE=false

usage() {
    echo "Usage: oedon janitor [--aggressive|-a] [--force|-f]"
    echo "  --aggressive : Perform deep cleanup (prune unused images, volumes, apt cache)"
    echo "  --force      : Skip confirmation prompts (useful for cron jobs)"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --aggressive|-a) AGGRESSIVE=true; shift ;;
        --force|-f)      FORCE=true; shift ;;
        --help|-h)       usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

get_disk_usage() {
    df / | tail -1 | awk '{print $5}' | sed 's/%//'
}

DISK_USAGE=$(get_disk_usage)
echo "[INFO] Initializing system cleanup (Janitor Mode)..."

# ----- Always safe cleanup -----
echo "[INFO] Cleaning Docker build cache (>24h)..."
docker builder prune -f --filter "until=24h" >/dev/null 2>&1 || true

echo "[INFO] Removing dangling Docker images..."
docker image prune -f >/dev/null 2>&1 || true

echo "[INFO] Vacuuming system journals (keeping 2 days)..."
sudo journalctl --vacuum-time=2d >/dev/null 2>&1 || true

echo "[INFO] Truncating container logs larger than 50MB..."
sudo find /var/lib/docker/containers -name "*.log" -type f -size +50M -exec truncate -s 0 {} \; 2>/dev/null || true

# ----- Aggressive cleanup (triggered by flag or disk threshold) -----
if [[ "$AGGRESSIVE" == true ]] || [[ "$DISK_USAGE" -ge "$THRESHOLD" ]]; then
    echo "[WARN] Disk usage is at ${DISK_USAGE}% (threshold: ${THRESHOLD}%)"
    
    if [[ "$FORCE" == false ]] && [[ "$AGGRESSIVE" == false ]]; then
        read -p "Disk critical. Perform aggressive cleanup? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "[INFO] Aggressive cleanup skipped. Run 'oedon janitor --aggressive' manually if needed."
            exit 0
        fi
    fi

    echo "[INFO] Starting aggressive cleanup..."
    echo "[INFO] Pruning all unused Docker images..."
    docker image prune -a -f >/dev/null 2>&1 || true
    echo "[INFO] Pruning stopped containers..."
    docker container prune -f >/dev/null 2>&1 || true
    echo "[INFO] Pruning unused Docker volumes..."
    docker volume prune -f >/dev/null 2>&1 || true
    echo "[INFO] Cleaning APT cache..."
    sudo apt clean >/dev/null 2>&1 || true
    sudo apt autoremove -y >/dev/null 2>&1 || true
    echo "[INFO] Aggressive cleanup completed."
fi

NEW_DISK=$(get_disk_usage)
echo "[OK] Disk usage: before ${DISK_USAGE}% -> after ${NEW_DISK}%"

if [[ "$NEW_DISK" -ge "$THRESHOLD" ]]; then
    echo "[CRITICAL] Disk usage still at ${NEW_DISK}%. Manual investigation required."
    # Optional: send alert (Telegram, webhook, etc.)
else
    echo "[OK] Disk usage below threshold."
fi
