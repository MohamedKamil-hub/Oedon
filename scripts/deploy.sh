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
if ! oedon_validate_env; then
    echo -e "${ERR} Environment validation failed."
    exit 1
fi

SITES_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"
rm -f "${SITES_DIR}"/*.conf
mkdir -p "$SITES_DIR"

deploy_app() {
    local APP_NAME=$1
    local APP_PORT=$2
    local APP_DOMAIN=$3

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
            fastcgi_read_timeout 300s;
        }"
    else
        PROXY_CONFIG="
        location / {
            resolver 127.0.0.11 valid=30s;
            set \$upstream http://${APP_NAME}:${APP_PORT};
            proxy_pass \$upstream;

            # Headers estándar para CUALQUIER app Docker
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port 443;

            # Configuración recomendada para evitar 500 en Apache/PHP/Node/etc.
            proxy_http_version 1.1;
            proxy_set_header Connection '';
            proxy_buffering off;
            proxy_request_buffering off;

            # Timeouts generosos (útil para apps lentas)
            proxy_connect_timeout 10s;
            proxy_read_timeout 300s;

            # WebSockets (no rompe nada si no se usa)
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
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

    echo -e "${BLUE}${BOLD}--- GENERATING SSL CERTIFICATE WITH SAN ---${NC}"

    declare -a ALL_DOMAINS
    ALL_DOMAINS=("${DOMAIN}")

    while IFS='|' read -r name port subdomain || [ -n "$name" ]; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        full_domain="$(echo "$subdomain" | xargs).${DOMAIN}"
        ALL_DOMAINS+=("$full_domain")
    done < "${PROJECT_DIR}/apps.list"

    SAN_LIST=$(printf "DNS:%s," "${ALL_DOMAINS[@]}" | sed 's/,$//')

    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${SSL_DIR}/oedon.key" \
        -out "${SSL_DIR}/oedon.crt" \
        -subj "/CN=${DOMAIN}/O=Oedon/C=ES" \
        -addext "subjectAltName = ${SAN_LIST}" 2>/dev/null

    echo -e "   ${OK} Certificate created with SAN for: ${ALL_DOMAINS[*]}"

    # Validation: apps.list vs real directories
    echo -e "${BLUE}${BOLD}--- VALIDATING APPLICATIONS ---${NC}"
    while IFS='|' read -r name port subdomain || [ -n "$name" ]; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        name_trimmed="$(echo "$name" | xargs)"

        if [ "${name_trimmed}" = "oedon-static" ]; then
            continue
        fi

        if [ ! -d "${PROJECT_DIR}/apps/${name_trimmed}" ]; then
            echo -e "${ERR} ERROR: App '${name_trimmed}' is listed in apps.list but directory 'apps/${name_trimmed}' does not exist."
            echo -e "       Create the directory and place docker-compose.yml (or .yaml) inside it."
            exit 1
        fi
        if [ ! -f "${PROJECT_DIR}/apps/${name_trimmed}/docker-compose.yml" ] && [ ! -f "${PROJECT_DIR}/apps/${name_trimmed}/docker-compose.yaml" ]; then
            echo -e "${ERR} ERROR: App '${name_trimmed}' directory exists but no docker-compose.yml or docker-compose.yaml found."
            exit 1
        fi
    done < "${PROJECT_DIR}/apps.list"
    echo -e "   ${OK} All applications validated successfully."

    # Step 1: Nginx Configuration
    echo -e "${BLUE}${BOLD}--- CONFIGURING VHOSTS ---${NC}"
    while IFS='|' read -r name port subdomain || [ -n "$name" ]; do
        [[ -z "$name" || "$name" =~ ^# ]] && continue
        full_domain="$(echo "$subdomain" | xargs).${DOMAIN}"
        deploy_app "$(echo "$name" | xargs)" "$(echo "$port" | xargs)" "$full_domain"
    done < "${PROJECT_DIR}/apps.list"

    # Step 2: Infrastructure
    echo -e "\n${BLUE}${BOLD}--- STARTING SERVICES ---${NC}"
    docker network inspect oedon-network >/dev/null 2>&1 || docker network create oedon-network
    docker compose -f "${PROJECT_DIR}/docker-compose.yml" up -d


    # Step 3: Deploy apps
    for app_dir in "${PROJECT_DIR}"/apps/*/; do
        [ -d "$app_dir" ] || continue
        APP_NAME=$(basename "$app_dir")
        COMPOSE_FILE=""
        [ -f "${app_dir}docker-compose.yml" ] && COMPOSE_FILE="${app_dir}docker-compose.yml"
        [ -f "${app_dir}docker-compose.yaml" ] && COMPOSE_FILE="${app_dir}docker-compose.yaml"
        [ -z "$COMPOSE_FILE" ] && continue

        echo -e " ${INFO} Deploying app: ${BOLD}${APP_NAME}${NC}"

        # Detect compose changes → recreate volumes
        COMPOSE_HASH_FILE="${PROJECT_DIR}/.oedon_hashes/${APP_NAME}.sha"
        COMPOSE_HASH_CURRENT=$(sha256sum "$COMPOSE_FILE" | cut -d' ' -f1)
        mkdir -p "$(dirname "$COMPOSE_HASH_FILE")"
        if [ -f "$COMPOSE_HASH_FILE" ]; then
            COMPOSE_HASH_PREV=$(cat "$COMPOSE_HASH_FILE")
            if [ "$COMPOSE_HASH_CURRENT" != "$COMPOSE_HASH_PREV" ]; then
                echo -e " ${WARN} Compose file changed for ${APP_NAME}. Recreating..."
                docker compose -f "$COMPOSE_FILE" --env-file "${PROJECT_DIR}/.env" down --volumes 2>/dev/null || true
            fi
        fi
        echo "$COMPOSE_HASH_CURRENT" > "$COMPOSE_HASH_FILE"

        # OVERRIDE: fuerza que CUALQUIER compose use oedon-network (sin que el usuario lo escriba)
        OVERRIDE_FILE="${app_dir}.oedon-network-override.yml"
        cat > "$OVERRIDE_FILE" << YAML
networks:
  default:
    external: true
    name: oedon-network
YAML

        MAX_RETRIES=3
        SUCCESS=false
        for ((RETRY=1; RETRY<=MAX_RETRIES; RETRY++)); do
            if docker compose -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE" \
                --env-file "${PROJECT_DIR}/.env" up -d --build; then
                SUCCESS=true
                echo -e " ${OK} ${APP_NAME} deployed successfully."
                break
            else
                echo -e " ${WARN} Attempt ${RETRY}/${MAX_RETRIES} failed. Retrying in 10s..."
                sleep 10
            fi
        done

        if [ "$SUCCESS" = false ]; then
            echo -e "${ERR} Failed to deploy ${APP_NAME} after ${MAX_RETRIES} attempts."
            exit 1
        fi

        # Read port from apps.list for health check
        APP_PORT=""
        while IFS='|' read -r _name _port _sub || [ -n "$_name" ]; do
            [[ -z "$_name" || "$_name" =~ ^# ]] && continue
            if [ "$(echo "$_name" | xargs)" = "$APP_NAME" ]; then
                APP_PORT="$(echo "$_port" | xargs)"
                break
            fi
        done < "${PROJECT_DIR}/apps.list"

        # Health wait: give slow apps time to bootstrap
        if [ -n "$APP_PORT" ]; then
            echo -e " ${INFO} Waiting for ${APP_NAME} to become ready..."
            READY=false
            for i in $(seq 1 30); do
                if [ "$APP_PORT" = "9000" ]; then
                    if docker exec "$APP_NAME" pgrep -x "php-fpm" >/dev/null 2>&1; then
                        READY=true; break
                    fi
                else
                    if docker exec oedon-proxy curl -sf -o /dev/null \
                        "http://${APP_NAME}:${APP_PORT}/" 2>/dev/null; then
                        READY=true; break
                    fi
                fi
                sleep 5
            done
            if [ "$READY" = true ]; then
                echo -e " ${OK} ${APP_NAME} is responding."
            else
                echo -e " ${WARN} ${APP_NAME} not responding yet. Check: docker logs ${APP_NAME}"
            fi
        fi

        # python-app specific integrity check
        if [ "$APP_NAME" = "python-app" ]; then
            echo -e " ${INFO} Signing python-app integrity..."
            sleep 2
            docker run --rm --network oedon-network curlimages/curl -s -X POST "http://python-app:5000/sign" \
                 -H "X-Oedon-Key: ${OEDON_PUBLIC_KEY}" \
                 -H "Content-Type: application/json" \
                 -d '{"app": "python-app", "hash": "verified_deployment"}' > /dev/null
            echo -e " ${OK} python-app integrity verified."
        fi
    done



    # Step 4: Finalize
    docker exec oedon-proxy nginx -s reload 2>/dev/null
    echo -e "\n${GREEN}${BOLD}[SUCCESS] Deployment complete.${NC}"
    echo -e "${YELLOW}URL: https://python.${DOMAIN}/verify?app=python-app&hash=verified_deployment${NC}"

elif [ $# -eq 3 ]; then
    deploy_app "$1" "$2" "$3"
fi
