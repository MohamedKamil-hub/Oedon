k#!/bin/bash
# setup-oedon.sh - Professional System Check for Oedon OS
set -euo pipefail

echo "🛡️  === OEDON OS - System Integrity Check ==="
echo ""

# 1. Directory Check
if [ ! -f "apps.list" ]; then
    echo "❌ ERROR: Run this from the root of the Oedon project (~/Oedon/)"
    exit 1
fi
echo "✓ Directory: $(pwd)"

# 2. Environment & Network
source .env
if docker network ls | grep -q "${NETWORK_NAME}"; then
    echo "✓ Network '${NETWORK_NAME}' is active"
else
    echo "✗ Network '${NETWORK_NAME}' missing. Creating it..."
    docker network create "${NETWORK_NAME}"
fi

# 3. SSL Check
if [ -f "${SSL_CERT}" ] && [ -f "${SSL_KEY}" ]; then
    echo "✓ SSL Certificates found at ${SSL_CERT}"
else
    echo "✗ SSL Certificates MISSING at ${SSL_CERT}"
fi

# 4. Apps Check (from apps.list)
echo ""
echo "=== REGISTERED APPLICATIONS ==="
grep -v '^#' apps.list | grep '|' | while read -r line; do
    app_name=$(echo "$line" | cut -d'|' -f1 | xargs)
    if [ -d "apps/$app_name" ]; then
        echo "✓ App folder found: $app_name"
    else
        echo "⚠️ WARNING: $app_name is in apps.list but folder apps/$app_name is missing!"
    fi
done

# 5. Options
echo ""
echo "=== ACTIONS ==="
echo "1) Sync Nginx (Apply apps.list)"
echo "2) Show Container Status"
echo "3) Exit"
read -p "Choose [1-3]: " option

case $option in
    1) sudo ./bin/oedon sync ;;
    2) ./bin/oedon status ;;
    3) exit 0 ;;
    *) echo "Invalid option"; exit 1 ;;
esac

echo ""
echo "🚀 Oedon is ready. Use 'oedon help' for more commands."
