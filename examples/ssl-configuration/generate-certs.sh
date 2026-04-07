#!/bin/bash
# Genera certificados auto-firmados para el ecosistema OEDON
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout oedon.key -out oedon.crt \
  -subj "/C=ES/ST=Madrid/L=Madrid/O=OEDON/CN=*.oedon.test"
