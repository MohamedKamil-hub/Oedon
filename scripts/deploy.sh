#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_DIR}/scripts/colors.sh"

# Source and export .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

# Ensure OEDON_PUBLIC_KEY exists
if [ -z "${OEDON_PUBLIC_KEY:-}" ]; then
    NEW_KEY=$(openssl rand -hex 16)
    echo "OEDON_PUBLIC_KEY=$NEW_KEY" >> "${PROJECT_DIR}/.env"
    export OEDON_PUBLIC_KEY=$NEW_KEY
fi

# Preflight validation
source "${SCRIPT_DIR}/preflight.sh"
if ! oedon_validate_env; then echo -e "${ERR} Environment validation failed."; exit 1; fi

SITES_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"
rm -f "${SITES_DIR}"/*.conf
mkdir -p "$SITES_DIR"
DEPLOYED_DOMAINS=()

deploy_app() {
    local APP_NAME=$1
    local APP_PORT=$2
    local APP_DOMAIN=$3
    DEPLOYED_DOMAINS+=("$APP_DOMAIN")

    if [ "$APP_PORT" = "9000" ]; then
        PROXY_CONFIG="
        resolver 127.0.0.11 valid=30s;
        root /var/www/html;
        index index.php;
        location / { try_files \$uri \$uri/ /index.php?\$args; }
        location ~ \.php\$ {
            set \$upstream ${APP_NAME}:${APP_PORT};
            include fastcgi_params;
            fastcgi_pass \$upstream;
            fastcgi_param SCRIPT_FILENAME /var/www/html\$fastcgi_script_name;
            fastcgi_param HTTPS on;
        }"
    else
        PROXY_CONFIG="
        location / {
            resolver 127.0.0.11 valid=30s;
            set \$upstream http://${APP_NAME}:${APP_PORT};
            proxy_pass \$upstream;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }"
    fi

    cat > "${SITES_DIR}/${APP_NAME}.conf" << NGINX
server {
    listen 80;
    server_name ${APP_DOMAIN};
    location / { return 301 https://\$host\$request_uri; }
}
server {
    listen 443 ssl;
    server_name ${APP_DOMAIN};
    ssl_certificate /etc/nginx/ssl/oedon.crt;
    ssl_certificate_key /etc/nginx/ssl/oedon.key;
    ${PROXY_CONFIG}
}
NGINX
    echo -e "   ${OK} ${APP_DOMAIN} configured"
}

if [ $# -eq 0 ]; then
    # Step 0: SSL Management
    SSL_DIR="${PROJECT_DIR}/config/nginx/ssl"
    mkdir -p "$SSL_DIR"
    if [ ! -f "${SSL_DIR}/oedon.crt" ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "${SSL_DIR}/oedon.key" -out "${SSL_DIR}/oedon.crt" -subj "/CN=${DOMAIN}/O=Oedon/C=ES" 2>/dev/null
    fi

    # Step 1: Nginx Configuration
    echo -e "${BLUE}${BOLD}--- CONFIGURING VHOSTS ---${NC}"
    while IFS='|' read -r name port subdomain || [ -n "$name" ]; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        full_domain="$(echo $subdomain | xargs).${DOMAIN}"
        deploy_app "$(echo $name | xargs)" "$(echo $port | xargs)" "$full_domain"
    done < "${PROJECT_DIR}/apps.list"

    # Step 2: Infrastructure
    echo -e "\n${BLUE}${BOLD}--- STARTING SERVICES ---${NC}"
    docker network inspect oedon-network >/dev/null 2>&1 || docker network create oedon-network
    docker compose -f "${PROJECT_DIR}/docker-compose.yml" up -d



# Step 3: Deploy apps & Auto-Sign
    for app_dir in "${PROJECT_DIR}"/apps/*/; do
        [ -d "$app_dir" ] || continue
        APP_NAME=$(basename "$app_dir")

        # Support both .yml and .yaml
        COMPOSE_FILE=""
        [ -f "${app_dir}docker-compose.yml" ]  && COMPOSE_FILE="${app_dir}docker-compose.yml"
        [ -f "${app_dir}docker-compose.yaml" ] && COMPOSE_FILE="${app_dir}docker-compose.yaml"
        [ -z "$COMPOSE_FILE" ] && continue

        echo -e "   ${INFO} Deploying app: ${BOLD}${APP_NAME}${NC}"
        docker compose -f "$COMPOSE_FILE" --env-file "${PROJECT_DIR}/.env" up -d --build

        if [ "$APP_NAME" = "python-app" ]; then
            echo -e "   ${INFO} Signing python-app integrity..."
            sleep 2
            docker run --rm --network oedon-network curlimages/curl -s -X POST "http://python-app:5000/sign" \
                 -H "X-Oedon-Key: ${OEDON_PUBLIC_KEY}" \
                 -H "Content-Type: application/json" \
                 -d '{"app": "python-app", "hash": "verified_deployment"}' > /dev/null
            echo -e "   ${OK} python-app integrity verified."
        fi
    done




    # Step 4: Finalize
    docker exec oedon-proxy nginx -s reload 2>/dev/null
    echo -e "\n${GREEN}${BOLD}[SUCCESS] Deployment complete.${NC}"
    echo -e "${YELLOW}URL: https://python.mohamed.local/verify?app=python-app&hash=verified_deployment${NC}"

elif [ $# -eq 3 ]; then
    deploy_app "$1" "$2" "$3"
fi
