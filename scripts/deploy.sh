#!/bin/bash
set -euo pipefail

# Esto asegura que el script sepa dónde está parado, no importa desde dónde lo llames
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Cargar variables (Asegúrate de que estas rutas existan)
SITES_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"



# ── Generar config Nginx (proxy universal con SSL) ──────

if [ "$APP_PORT" == "9000" ]; then
    # Configuración específica para PHP-FPM (Alpine)
    PROXY_CONFIG="
        include fastcgi_params;
        fastcgi_split_path_info ^(.+\\.php)(/.+)\$;
        fastcgi_pass ${APP_NAME}:${APP_PORT};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME /var/www/html\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param HTTPS on;
    "
else
    # Configuración genérica para HTTP (Python, Node, Apache, etc)
    PROXY_CONFIG="
        proxy_pass http://${APP_NAME}:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 60s;
    "
fi

# Un solo bloque para crear el archivo
cat > "${SITES_DIR}/${APP_NAME}.conf" << NGINX
server {
    listen 80;
    server_name ${APP_DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name ${APP_DOMAIN};

    ssl_certificate /etc/nginx/ssl/$(basename "$SSL_CERT");
    ssl_certificate_key /etc/nginx/ssl/$(basename "$SSL_KEY");

    # Cabeceras de seguridad (aplican a todas las apps)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Bloque raíz: PHP o HTTP según el puerto
    location / {
        ${PROXY_CONFIG}
    }

    # Si es FPM, a veces Nginx necesita una regla location específica para .php
    # La inyectamos solo si es el puerto 9000
    $(if [ "$APP_PORT" == "9000" ]; then
        echo "
    location ~ \\.php\$ {
        ${PROXY_CONFIG}
    }
        "
    fi)
}
NGINX
