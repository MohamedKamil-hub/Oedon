#!/bin/bash
# scripts/sync-apps.sh — Oedon App Synchronizer
# Lee apps.list y aplica la configuración de todas las apps declaradas.
# Esto es IaC: tu servidor entero está definido en un archivo de texto.
#
# Uso: ./scripts/sync-apps.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APPS_LIST="${PROJECT_DIR}/apps.list"
DEPLOY="${SCRIPT_DIR}/deploy.sh"
DRY_RUN=false

[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

[ -f "$APPS_LIST" ] || { echo "[!] apps.list no encontrado en ${PROJECT_DIR}"; exit 1; }
[ -f "$DEPLOY" ]    || { echo "[!] deploy.sh no encontrado en ${SCRIPT_DIR}"; exit 1; }

chmod +x "$DEPLOY"

echo "=== Oedon sync-apps ==="
[ "$DRY_RUN" = true ] && echo "[i] DRY RUN — no se aplican cambios"
echo ""

COUNT=0
ERRORS=0

while IFS= read -r line; do
    # Ignorar comentarios y líneas vacías (bug fix del original)
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Parsear campos separados por |
    IFS='|' read -r name port domain <<< "$line"

    # Limpiar espacios
    name="$(echo "$name" | xargs)"
    port="$(echo "$port" | xargs)"
    domain="$(echo "$domain" | xargs)"

    # Validar que los tres campos existen
    if [ -z "$name" ] || [ -z "$port" ] || [ -z "$domain" ]; then
        echo "[!] Línea malformada (necesita: nombre | puerto | dominio): '$line'"
        (( ERRORS++ )) || true
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "[dry] $name → https://${domain} (puerto ${port})"
    else
        echo "[*] Sincronizando: $name"
        if bash "$DEPLOY" "$name" "$port" "$domain"; then
            (( COUNT++ )) || true
        else
            echo "[!] Error desplegando $name"
            (( ERRORS++ )) || true
        fi
        echo ""
    fi

done < "$APPS_LIST"

echo "=== Sync completado: ${COUNT} apps desplegadas, ${ERRORS} errores ==="
