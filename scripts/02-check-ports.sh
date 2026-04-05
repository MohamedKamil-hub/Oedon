#!/bin/bash
# Check if required ports are available

PORTS=(80 443)
FAIL=0

for PORT in "${PORTS[@]}"; do
    if ss -tlnp | grep -q ":$PORT "; then
        echo " Port $PORT is already in use."
        FAIL=1
    fi
done

if [ $FAIL -eq 1 ]; then
    echo ""
    echo "Nebula needs ports 80 and 443 for Nginx Proxy Manager."
    echo "   Please stop any service using these ports:"
    echo "   - Apache:  sudo systemctl stop apache2"
    echo "   - Nginx:   sudo systemctl stop nginx"
    echo "   - Other:   use 'sudo ss -tlnp' to identify the process"
    echo ""
    exit 1
fi

echo " Ports 80 and 443 are available."
exit 0
