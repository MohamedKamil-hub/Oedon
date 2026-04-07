#!/bin/bash
# Generates random secrets for all CHANGE_ME values in .env
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"

[ -f "$ENV_FILE" ] || { echo "[!] .env not found"; exit 1; }

replace_secret() {
    local key="$1"
    local current
    current=$(grep "^${key}=" "$ENV_FILE" | cut -d= -f2)
    if [ "$current" = "CHANGE_ME" ] || [ -z "$current" ]; then
        local new_val
        new_val=$(openssl rand -hex 32)
        sed -i "s|^${key}=.*|${key}=${new_val}|" "$ENV_FILE"
        echo "[✓] ${key} generated"
    else
        echo "[i] ${key} already set, skipping"
    fi
}

replace_secret "PORTERO_SECRET"
replace_secret "OEDON_PUBLIC_KEY"

echo ""
echo "[✓] Secrets check complete. Review your .env:"
grep -E "^(PORTERO_SECRET|OEDON_PUBLIC_KEY)=" "$ENV_FILE" | cut -c1-60
