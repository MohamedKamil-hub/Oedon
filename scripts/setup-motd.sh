#!/bin/bash
# setup-motd.sh - Instala btop y configura MOTD con oedon-stats
# Ejecutar como root o con sudo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATS_SCRIPT="${SCRIPT_DIR}/oedon-stats.sh"

echo "[*] Instalando btop..."
if command -v apt &>/dev/null; then
    apt update -qq && apt install -y -qq btop
elif command -v dnf &>/dev/null; then
    dnf install -y btop
elif command -v pacman &>/dev/null; then
    pacman -Sy --noconfirm btop
else
    echo "[!] Package manager no detectado. Instala btop manualmente."
fi

echo "[*] Configurando oedon-stats.sh..."
chmod +x "$STATS_SCRIPT"

# ── Instalar como MOTD ──────────────────────────────────
# Desactivar MOTDs por defecto de Ubuntu/Debian
[ -d /etc/update-motd.d ] && chmod -x /etc/update-motd.d/* 2>/dev/null || true

# Crear enlace en update-motd.d (método estándar Debian/Ubuntu)
ln -sf "$STATS_SCRIPT" /etc/update-motd.d/99-oedon-stats
chmod +x /etc/update-motd.d/99-oedon-stats

# Limpiar /etc/motd estático si existe
[ -f /etc/motd ] && : > /etc/motd

# Asegurar que PAM ejecuta los scripts de motd
if [ -f /etc/pam.d/sshd ]; then
    grep -q "pam_motd" /etc/pam.d/sshd || {
        echo "session optional pam_motd.so motd=/run/motd.dynamic" >> /etc/pam.d/sshd
    }
fi

# Asegurar PrintMotd en sshd_config
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/^#\?PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config
    # PrintMotd=no porque PAM se encarga via pam_motd
fi

echo "[✓] MOTD configurado. oedon-stats.sh se ejecutará en cada login SSH."
echo "[✓] btop instalado. Ejecuta 'btop' para monitoreo interactivo."
echo ""
echo "[i] Para probar ahora: bash ${STATS_SCRIPT}"
