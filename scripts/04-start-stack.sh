#!/bin/bash
cd "$(dirname "$0")/.."
docker compose up -d
echo " Nebula stack started."
echo "   • NPM admin: http://<your-vm-ip>:81"
echo "   • Netdata:   http://<your-vm-ip>:19999"
