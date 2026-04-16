#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

NGINX_LOG_PATH="/var/log/oedon/nginx"

echo "=== OEDON FAIL2BAN CONFIGURATION ==="

mkdir -p "$NGINX_LOG_PATH"
touch "${NGINX_LOG_PATH}/access.log" "${NGINX_LOG_PATH}/error.log"
mkdir -p /etc/fail2ban/jail.d /etc/fail2ban/filter.d /etc/fail2ban/action.d

TARGET_SSH_PORT="${SSH_PORT:-22}"

# ── Custom dual-chain action ──────────────────────────────────────────────────
# Bans on INPUT (blocks SSH and all host-level traffic) AND
# DOCKER-USER (blocks traffic reaching containers).
# This means a banned IP is cut off from everything simultaneously.
tee /etc/fail2ban/action.d/iptables-oedon.conf > /dev/null << 'ACTION'
[Definition]
actionstart = iptables -N f2b-oedon-INPUT  2>/dev/null || true
              iptables -N f2b-oedon-DOCKER  2>/dev/null || true
              iptables -I INPUT       1 -j f2b-oedon-INPUT
              iptables -I DOCKER-USER 1 -j f2b-oedon-DOCKER

actionstop  = iptables -D INPUT       -j f2b-oedon-INPUT  2>/dev/null || true
              iptables -D DOCKER-USER -j f2b-oedon-DOCKER 2>/dev/null || true
              iptables -F f2b-oedon-INPUT  2>/dev/null || true
              iptables -F f2b-oedon-DOCKER 2>/dev/null || true
              iptables -X f2b-oedon-INPUT  2>/dev/null || true
              iptables -X f2b-oedon-DOCKER 2>/dev/null || true

actionban   = iptables -I f2b-oedon-INPUT  1 -s <ip> -j DROP
              iptables -I f2b-oedon-DOCKER 1 -s <ip> -j DROP

actionunban = iptables -D f2b-oedon-INPUT  -s <ip> -j DROP 2>/dev/null || true
              iptables -D f2b-oedon-DOCKER -s <ip> -j DROP 2>/dev/null || true

[Init]
name = oedon
ACTION

# ── Global configuration ──────────────────────────────────────────────────────
# ignoreip = localhost ONLY. No private ranges whitelisted.
# This is intentional: the product demo requires that any IP, including
# the operator's LAN IP, gets fully banned after the threshold.
# Use: sudo oedon unban <ip>   (works from VirtualBox console via local login)
tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8 ::1
banaction = iptables-oedon

[sshd]
enabled  = true
port     = ${TARGET_SSH_PORT}
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
action   = iptables-oedon
EOF

# ── Nginx jails ───────────────────────────────────────────────────────────────
# All jails use iptables-oedon so every ban kills INPUT + DOCKER-USER.
tee /etc/fail2ban/jail.d/oedon-nginx.local > /dev/null << EOF
[nginx-auth]
enabled  = true
port     = http,https
filter   = nginx-auth
logpath  = ${NGINX_LOG_PATH}/access.log
backend  = polling
maxretry = 5
findtime = 300
bantime  = 3600
action   = iptables-oedon

[nginx-botscan]
enabled  = true
port     = http,https
filter   = nginx-botscan
logpath  = ${NGINX_LOG_PATH}/access.log
backend  = polling
maxretry = 3
findtime = 300
bantime  = 86400
action   = iptables-oedon

[nginx-badbots]
enabled  = true
port     = http,https
filter   = nginx-badbots
logpath  = ${NGINX_LOG_PATH}/access.log
backend  = polling
maxretry = 1
bantime  = 86400
action   = iptables-oedon

[wordpress]
enabled  = true
port     = http,https
filter   = wordpress
logpath  = ${NGINX_LOG_PATH}/access.log
backend  = polling
maxretry = 3
findtime = 300
bantime  = 3600
action   = iptables-oedon
EOF

# ── Filters ───────────────────────────────────────────────────────────────────
tee /etc/fail2ban/filter.d/nginx-auth.conf > /dev/null << 'FILTER'
[Definition]
failregex = ^<HOST> .* "POST .*(wp-login\.php|xmlrpc\.php|/login|/admin|/user/login|/auth|/signin|/api/auth|/account/login).*" (200|401|403|429) .*$
            ^<HOST> .* "POST .*(wp-login\.php|xmlrpc\.php).*" 200 .*$
ignoreregex = ^<HOST> .* "GET .*(\.css|\.js|\.png|\.jpg|\.ico|\.svg|\.woff)" .*$
FILTER

tee /etc/fail2ban/filter.d/wordpress.conf > /dev/null << 'FILTER'
[Definition]
failregex = ^<HOST> .* "POST /wp-login\.php.*" 200
            ^<HOST> .* "POST /xmlrpc\.php.*" 200
ignoreregex =
FILTER

tee /etc/fail2ban/filter.d/nginx-botscan.conf > /dev/null << 'FILTER'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .*(\.env|\.git|/\.well-known/security\.txt|phpmyadmin|/setup\.php|/install\.php|/config\.php|/administrator|/solr|/actuator).*" (403|404|444) .*$
            ^<HOST> .* "(GET|POST|HEAD) .*" 400 .*$
ignoreregex =
FILTER

tee /etc/fail2ban/filter.d/nginx-badbots.conf > /dev/null << 'FILTER'
[Definition]
failregex = ^<HOST> .* ".*" \d+ \d+ ".*" ".*(sqlmap|nikto|nmap|dirbuster|gobuster|masscan|zgrab|python-requests/2\.\d+|Go-http-client|curl/\d).*"$
ignoreregex =
FILTER

# ── Ensure ESTABLISHED traffic is always accepted in DOCKER-USER ──────────────
iptables -C DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
    iptables -I DOCKER-USER 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

systemctl enable fail2ban
systemctl restart fail2ban
sleep 2

echo ""
fail2ban-client status
echo ""

for jail in sshd nginx-auth nginx-botscan nginx-badbots wordpress; do
    if fail2ban-client status "$jail" >/dev/null 2>&1; then
        echo "   [OK] ${jail} is active"
    else
        echo "   [WARN] ${jail} failed to start — check: journalctl -u fail2ban"
    fi
done

echo ""
echo "------------------------------------------------"
echo " Fail2Ban configured."
echo " Ban scope: INPUT (SSH) + DOCKER-USER (containers)"
echo " No IP whitelist — any IP can be banned."
echo " To unban: sudo oedon unban <ip>"
echo "------------------------------------------------"
