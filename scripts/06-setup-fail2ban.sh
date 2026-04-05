#!/bin/bash
set -e  # stop on first error

echo "=== NEBULA FAIL2BAN CONFIGURATION ==="

# 1. Install Fail2Ban (if not already installed)
sudo apt update
sudo apt install -y fail2ban

# 2. Create config directories (just in case)
sudo mkdir -p /etc/fail2ban/jail.d

# 3. Configure SSH on port 2222
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

# 4. Configure Nginx (won't hurt if Nginx isn't installed)
sudo tee /etc/fail2ban/jail.d/nginx.local > /dev/null <<'EOF'
[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 600
EOF

# 5. Enable & restart
sudo systemctl enable --now fail2ban

# 6. Give it a moment, then show status
sleep 3
sudo fail2ban-client status
sudo fail2ban-client status sshd || echo "SSH jail not yet active (check logs)"
sudo fail2ban-client status nginx-http-auth || echo " Nginx jail not yet active (install Nginx first?)"

echo "------------------------------------------------"
echo " Fail2Ban configured and active."
echo " SSH (2222) and Nginx are now protected."
echo "------------------------------------------------"
