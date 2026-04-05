#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSL_DIR="${PROJECT_DIR}/config/nginx/ssl"

mkdir -p "$SSL_DIR"

# Cargar .env si existe
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"
DOMAIN="${DOMAIN:-oedon.test}"

echo "[*] Generando certificado autofirmado para *.${DOMAIN}"

openssl req -x509 -nodes -days 3650 \
  -newkey rsa:2048 \
  -keyout "${SSL_DIR}/oedon.key" \
  -out "${SSL_DIR}/oedon.crt" \
  -subj "/CN=*.${DOMAIN}" \
  -addext "subjectAltName=DNS:*.${DOMAIN},DNS:${DOMAIN}"

echo "[✓] Certificados generados en ${SSL_DIR}/"
ls -la "${SSL_DIR}/"
