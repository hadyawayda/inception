#!/bin/sh
set -e

# Use DOMAIN_NAME from env (.env)
: "${DOMAIN_NAME:=localhost}"

if [ ! -f /etc/nginx/ssl/server.key ] || [ ! -f /etc/nginx/ssl/server.crt ]; then
  openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/server.key \
    -out /etc/nginx/ssl/server.crt \
    -subj "/C=FR/ST=42/L=Paris/O=Inception/OU=42/CN=${DOMAIN_NAME}"
fi

exec "$@"
