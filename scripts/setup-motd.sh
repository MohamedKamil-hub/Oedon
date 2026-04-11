#!/bin/bash
# OEDON - MOTD Setup Service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/colors.sh"
STATS_SCRIPT="${SCRIPT_DIR}/oedon-stats.sh"

# 1. Interactive confirmation
echo -e -n "${CYAN}${BOLD}[?] Do you want to enable the Oedon dynamic MOTD and monitoring? (y/N): ${NC}"
read -r confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${INFO} MOTD configuration skipped."
    exit 0
fi

# 2. Dependencies
echo -e "${INFO} Installing btop monitoring..."
if command -v apt &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq btop >/dev/null 2>&1
elif command -v dnf &>/dev/null; then
    dnf install -y -q btop >/dev/null 2>&1
else
    echo -e "${WARN} Supported package manager not found. Install 'btop' manually."
fi

# 3. Stats script permissions
echo -e "${INFO} Configuring execution permissions for ${STATS_SCRIPT}..."
chmod +x "$STATS_SCRIPT"

# 4. Standard MOTD Implementation (Debian/Ubuntu)
if [ -d /etc/update-motd.d ]; then
    echo -e "${INFO} Disabling default system MOTDs..."
    chmod -x /etc/update-motd.d/* 2>/dev/null || true
    
    echo -e "${INFO} Linking Oedon stats to update-motd.d..."
    ln -sf "$STATS_SCRIPT" /etc/update-motd.d/99-oedon-stats
    chmod +x /etc/update-motd.d/99-oedon-stats
fi

# 5. Clean static MOTD
if [ -f /etc/motd ]; then
    : > /etc/motd
fi

# 6. SSH Configuration for Dynamic MOTD
echo -e "${INFO} Tuning SSHD configuration for dynamic MOTD..."
if [ -f /etc/ssh/sshd_config ]; then
    # Disable static PrintMotd to let PAM handle the dynamic one
    sed -i 's/^#\?PrintMotd.*/PrintMotd no/' /etc/ssh/sshd_config
fi

if [ -f /etc/pam.d/sshd ]; then
    if ! grep -q "pam_motd" /etc/pam.d/sshd; then
        echo "session optional pam_motd.so motd=/run/motd.dynamic" >> /etc/pam.d/sshd
    fi
fi

echo -e "${OK} MOTD configured. oedon-stats.sh will execute on every SSH login."
echo -e "${OK} btop installed. Run 'btop' for interactive monitoring."
echo -e "\n${INFO} Test it now by running: bash ${STATS_SCRIPT}"
