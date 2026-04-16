#!/bin/bash
# OEDON - Master Installer
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERR] Must run as root: sudo bash install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

if [ -f "$SCRIPT_DIR/scripts/colors.sh" ]; then
    source "$SCRIPT_DIR/scripts/colors.sh"
else
    BOLD='' NC='' RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
    OK='[OK]' ERR='[ERR]' INFO='[INFO]' SSL='[SSL]' WARN='[WARN]'
fi

echo -e "${BLUE}${BOLD}--- OEDON MASTER INSTALLATION STARTED ---${NC}"

# Robust apt update with retries and mirror fallback
apt_retry_update() {
    local max_attempts=3
    local attempt=1
    local wait_time=2

    while [ $attempt -le $max_attempts ]; do
        echo -e "   ${INFO} apt update (attempt $attempt/$max_attempts)..."
        # Bypass date/hash checks – common during mirror sync
        if apt-get update -qq -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false; then
            echo -e "   ${OK} apt update successful."
            return 0
        else
            echo -e "   ${WARN} apt update failed (code $?)."
            if [ $attempt -lt $max_attempts ]; then
                echo -e "   ${INFO} Retrying in ${wait_time}s..."
                sleep $wait_time
                wait_time=$((wait_time * 2))
            fi
        fi
        attempt=$((attempt + 1))
    done

    # Last resort: clean cache and switch to main Ubuntu mirror
    echo -e "   ${WARN} Persistent failures. Cleaning cache and trying main mirror..."
    rm -rf /var/lib/apt/lists/*
    sed -i 's|http://[^ ]*archive.ubuntu.com|http://archive.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null || true

    if apt-get update -qq --fix-missing; then
        echo -e "   ${OK} Forced update succeeded."
        return 0
    fi

    echo -e "   ${ERR} Unable to update package lists after $max_attempts attempts."
    return 1
}

# 1. Environment template only
echo -e "\n${BLUE}${BOLD}STEP 1: ENVIRONMENT SETUP${NC}"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    chown "${REAL_USER}:${REAL_USER}" "$SCRIPT_DIR/.env"
    echo -e "   ${OK} .env template created. Configure it before deploy."
else
    echo -e "   ${OK} .env file already exists."
fi

echo -e "${INFO} Configuring System Guardian (Watchdog)..."
( sudo -u "$REAL_USER" crontab -l 2>/dev/null | grep -v "oedon-watchdog.sh"
  echo "*/5 * * * * bash ${SCRIPT_DIR}/scripts/oedon-watchdog.sh"
) | sudo -u "$REAL_USER" crontab -
echo -e "   ${OK} Watchdog registered in crontab."

# 2. Dependencies
echo -e "\n${BLUE}${BOLD}STEP 2: SYSTEM DEPENDENCIES${NC}"

echo -e "   ${INFO} Installing system dependencies (acl, fail2ban, ufw, etc)..."
apt_retry_update || {
    echo -e "   ${WARN} Could not refresh package lists; continuing with cached data."
}
if ! apt-get install -y ca-certificates curl gnupg lsb-release acl fail2ban ufw libnss3-tools; then
    echo -e "   ${ERR} Failed to install system dependencies. Trying to fix broken packages..."
    apt-get install -f -y
    apt-get install -y ca-certificates curl gnupg lsb-release acl fail2ban ufw libnss3-tools || {
        echo -e "   ${ERR} Could not install required packages. Exiting."
        exit 1
    }
fi
echo -e "   ${OK} System dependencies installed."

echo -e "   ${INFO} Installing Docker Engine..."
bash "$SCRIPT_DIR/scripts/01-install-docker.sh"

# === IPv6 FIX + daemon.json (obligatorio para que funcione en cualquier red) ===
echo -e " ${INFO} Applying Docker daemon configuration (ipv6 disabled)..."
mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ] || ! grep -q '"ipv6"' /etc/docker/daemon.json 2>/dev/null; then
    cp "$SCRIPT_DIR/config/docker/daemon.json.example" /etc/docker/daemon.json
    echo -e " ${OK} daemon.json installed from config/docker/daemon.json.example"
else
    echo -e " ${OK} daemon.json already exists and has ipv6 setting"
fi
systemctl restart docker
sleep 2
echo -e " ${OK} Docker daemon restarted with new configuration"

usermod -aG docker "${REAL_USER}"

if [ -S /var/run/docker.sock ]; then
    chown root:docker /var/run/docker.sock
    setfacl -m "u:${REAL_USER}:rw" /var/run/docker.sock || chmod 666 /var/run/docker.sock
fi
echo -e "   ${OK} Docker group assigned and socket permissions granted."

echo -e "   ${INFO} Securing app directories for Nginx..."
# Forzamos la creación de las carpetas que Git ignora si están vacías
mkdir -p "$SCRIPT_DIR/apps/wordpress/html"
mkdir -p "$SCRIPT_DIR/apps/static/html"
# Damos permiso al grupo de Nginx (www-data) para que no de Error 403
setfacl -R -m g:www-data:rwx "$SCRIPT_DIR/apps/" 2>/dev/null || true
setfacl -R -d -m g:www-data:rwx "$SCRIPT_DIR/apps/" 2>/dev/null || true

systemctl enable fail2ban --now >/dev/null 2>&1
echo -e "   ${OK} Security tools configured."

echo -e "   ${SSL} Provisioning mkcert for trusted local SSL..."
if ! command -v mkcert >/dev/null 2>&1; then
    wget -q -O /usr/local/bin/mkcert "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    chmod +x /usr/local/bin/mkcert
fi
sudo -u "$REAL_USER" mkcert -install >/dev/null 2>&1
echo -e "   ${OK} mkcert initialized."

# 3. CLI Configuration
echo -e "\n${BLUE}${BOLD}STEP 3: CLI CONFIGURATION${NC}"
BIN_SOURCE="$SCRIPT_DIR/bin/oedon"

if [ ! -f "$BIN_SOURCE" ]; then
    echo -e "   ${ERR} Critical error: bin/oedon not found."
    exit 1
fi
chmod +x "$BIN_SOURCE"

echo -e "   ${INFO} Running pre-install binary diagnostics..."
for DIR in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /snap/bin; do
    rm -f "${DIR}/oedon" 2>/dev/null || true
done

echo -e "   ${INFO} Creating CLI wrapper in /usr/local/bin/oedon..."
tee /usr/local/bin/oedon > /dev/null << WRAPPER
#!/bin/bash
exec "${BIN_SOURCE}" "\$@"
WRAPPER
chmod +x /usr/local/bin/oedon

WHICH_OEDON=$(which oedon 2>/dev/null || echo "NOT FOUND")
if [ "$WHICH_OEDON" == "/usr/local/bin/oedon" ] && oedon help > /dev/null 2>&1; then
    echo -e "   ${OK} 'oedon' CLI command verified and ready."
else
    echo -e "   ${ERR} CLI installation failed. Path: $WHICH_OEDON"
    exit 1
fi

# 4. Dynamic App Symlinks
echo -e "\n${BLUE}${BOLD}STEP 4: APP ORCHESTRATION${NC}"
echo -e "   ${INFO} Linking environment files to apps..."
for app_dir in "$SCRIPT_DIR"/apps/*/; do
    [ -d "$app_dir" ] || continue
    if [ -f "${app_dir}docker-compose.yml" ] || [ -f "${app_dir}docker-compose.yaml" ]; then
        ln -sf "../../.env" "${app_dir}.env"
    fi
done
echo -e "   ${OK} Symlinks created for all app directories."

# 5. Log directory
echo -e "\n${BLUE}${BOLD}STEP 5: LOG INFRASTRUCTURE${NC}"
mkdir -p /var/log/oedon/nginx
chown -R "${REAL_USER}:${REAL_USER}" /var/log/oedon
echo -e "   ${OK} Log directories created."

# 6. Portero Digital Setup
echo -e "\n${BLUE}${BOLD}STEP 6: SECURITY SERVICES (PORTERO)${NC}"
echo -e "   ${INFO} Configuring Port Knocking Daemon..."

PORTERO_SRC="$SCRIPT_DIR/internal/portero/portero.py"
SERVICE_SRC="$SCRIPT_DIR/internal/portero/oedon-portero.service"

mkdir -p /opt/oedon-portero
cp "$PORTERO_SRC" "$SCRIPT_DIR/.env" /opt/oedon-portero/
cp "$SERVICE_SRC" /etc/systemd/system/

systemctl daemon-reload
systemctl enable oedon-portero --now >/dev/null 2>&1
echo -e "   ${OK} Portero service is active."

echo -e "\n${GREEN}${BOLD}--- INSTALLATION COMPLETE ---${NC}"
echo -e "${INFO} Next step: ${BOLD}sudo oedon deploy${NC}"
echo -e "${INFO} The first deploy will configure your .env automatically.\n"
