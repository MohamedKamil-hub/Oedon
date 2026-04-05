#!/bin/bash
# setup-nebula.sh - Simple and secure setup for Nebula PaaS

echo "=== NEBULA PAAS - System Check ==="
echo ""

# 1. Check that we are in the correct location
if [ ! -f "docker-compose.yml" ]; then
    echo " ERROR: Run this from ~/nebula-selfhosted-paas/"
    exit 1
fi

echo "✓ Correct directory: $(pwd)"

# 2. Check Docker
if ! command -v docker &> /dev/null; then
    echo " ERROR: Docker is not installed."
    echo "   First run: ./scripts/01-install-docker.sh"
    exit 1
fi
echo "✓ Docker installed"

# 3. Show current status
echo ""
echo "=== CURRENT STATUS ==="

# Network
if docker network ls | grep -q nebula-network; then
    echo "✓ Network 'nebula-network' exists"
else
    echo "✗ Network 'nebula-network' does not exist"
fi

# SSL Certificates
if [ -f "certs/nebula.crt" ] && [ -f "certs/nebula.key" ]; then
    echo "✓ SSL certificates in certs/"
else
    echo "✗ SSL certificates not found in certs/"
fi

if [ -f "data/npm/ssl/nebula.crt" ] && [ -f "data/npm/ssl/nebula.key" ]; then
    echo "✓ SSL certificates in data/npm/ssl/"
else
    echo "✗ SSL certificates not found in data/npm/ssl/"
fi

# Applications
if [ -f "apps/wordpress-app/docker-compose.yaml" ]; then
    echo "✓ WordPress configured"
fi

if [ -f "apps/python-app/docker-compose.yml" ]; then
    echo "✓ Python App configured"
fi

# 4. Ask what to do
echo ""
echo "=== OPTIONS ==="
echo "1) Create Docker network (if missing)"
echo "2) Copy certificates to NPM (if missing)"
echo "3) Do everything (1 + 2)"
echo "4) Just show status (exit)"
read -p "Choose [1-4]: " option

case $option in
    1)
        # Create network
        if ! docker network ls | grep -q nebula-network; then
            docker network create nebula-network
            echo "✓ Network 'nebula-network' created"
        else
            echo "✓ Network already exists"
        fi
        ;;

    2)
        # Copy certificates if missing
        if [ -f "certs/nebula.crt" ] && [ -f "certs/nebula.key" ]; then
            if [ ! -f "data/npm/ssl/nebula.crt" ] || [ ! -f "data/npm/ssl/nebula.key" ]; then
                cp certs/nebula.crt data/npm/ssl/
                cp certs/nebula.key data/npm/ssl/
                echo "✓ Certificates copied to data/npm/ssl/"
            else
                echo "✓ Certificates already exist in data/npm/ssl/"
            fi
        else
            echo " No certificates in certs/ to copy"
        fi
        ;;

    3)
        # Network
        if ! docker network ls | grep -q nebula-network; then
            docker network create nebula-network
            echo "✓ Network 'nebula-network' created"
        else
            echo "✓ Network already exists"
        fi

        # Certificates
        if [ -f "certs/nebula.crt" ] && [ -f "certs/nebula.key" ]; then
            if [ ! -f "data/npm/ssl/nebula.crt" ] || [ ! -f "data/npm/ssl/nebula.key" ]; then
                cp certs/nebula.crt data/npm/ssl/
                cp certs/nebula.key data/npm/ssl/
                echo "✓ Certificates copied to data/npm/ssl/"
            else
                echo "✓ Certificates already exist in data/npm/ssl/"
            fi
        else
            echo " No certificates in certs/ to copy"
        fi
        ;;

    4)
        echo "Exiting..."
        exit 0
        ;;

    *)
        echo " Invalid option"
        exit 1
        ;;
esac

# 5. Show final instructions
echo ""
echo "=== INSTRUCTIONS ==="
echo "To bring everything up:"
echo "  docker compose up -d"
echo "  cd apps/wordpress-app && docker compose up -d"
echo "  cd apps/python-app && docker compose up -d"
echo ""
echo "Control panel: http://localhost:81"
echo "  User: admin@example.com"
echo "  Password: changeme"
echo ""
echo "Other available scripts:"
echo "  ./scripts/05-setup-firewall.sh  # Setup firewall"
echo "  ./scripts/99-backup.sh          # Make backup"
