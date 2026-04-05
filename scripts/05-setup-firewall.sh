#!/bin/bash
# ./scripts/05-setup-firewall.sh
# NEBULA - Firewall Configuration Script

echo "=== NEBULA FIREWALL CONFIGURATION ==="

# 1. Reset and policies
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 2. Main rules
echo "Configuring rules..."

# SSH Brute-force protection
sudo ufw limit 2222/tcp comment 'SSH protected (6 tries/30s)'

# Web & Service ports
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 10443/tcp comment 'HTTPS alternative port for Windows/WSL2 conflicts'
sudo ufw allow 19999/tcp comment 'Netdata monitoring'
sudo ufw allow 81/tcp comment 'Nginx Proxy Manager admin'

# 3. Activate firewall
sudo ufw --force enable

echo "------------------------------------------------"
echo " Firewall configured and enabled."
echo "                                "
echo "PORTS OPENED:"
echo "  • 2222/tcp  - SSH (rate limited)"
echo "  • 80/tcp    - HTTP"
echo "  • 443/tcp   - HTTPS (standard)"
echo "  • 10443/tcp - HTTPS alternative (Windows/WSL2 compatibility)"
echo "  • 19999/tcp - Netdata monitoring"
echo "  • 81/tcp    - NPM admin panel"
echo ""
echo " ! CAUTION: SSH has rate limiting (6 tries/30s)"
echo "For development: 'sudo ufw allow 2222/tcp' removes limit"
echo "------------------------------------------------"

sudo ufw status verbose
