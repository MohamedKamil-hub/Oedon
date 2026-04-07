#!/bin/bash
# ./scripts/05-setup-firewall.sh
# OEDON - Firewall Configuration (Fortress Mode)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Load .env ───────────────────────────────────────────
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

SSH_PORT="${SSH_PORT:-2222}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
PORTERO_UDP_PORT="${PORTERO_UDP_PORT:-62201}"

echo "=== OEDON FIREWALL CONFIGURATION ==="

# 1. Reset and policies
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 2. Rules from .env
echo "Configuring rules..."

sudo ufw allow "${HTTP_PORT}/tcp" comment 'HTTP'
sudo ufw allow "${HTTPS_PORT}/tcp" comment 'HTTPS'
sudo ufw allow "${PORTERO_UDP_PORT}/udp" comment 'Oedon Portero Knock'

# SSH is NOT opened — portero handles it dynamically
# If you need emergency access: sudo ufw allow ${SSH_PORT}/tcp

# 3. Activate
sudo ufw --force enable

echo "------------------------------------------------"
echo " Firewall configured (Fortress Mode)"
echo ""
echo " PORTS OPEN:"
echo "   ${HTTP_PORT}/tcp   - HTTP"
echo "   ${HTTPS_PORT}/tcp  - HTTPS"
echo "   ${PORTERO_UDP_PORT}/udp  - Portero Knock"
echo ""
echo "------------------------------------------------"

sudo ufw status verbose
