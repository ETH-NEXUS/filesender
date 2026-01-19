#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-localhost}"
DAYS="${2:-365}"

CERT_DIR="/etc/nginx/ssl"
KEY_FILE="${CERT_DIR}/${DOMAIN}.key"
CERT_FILE="${CERT_DIR}/${DOMAIN}.crt"

mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"

# Create a self-signed cert with SAN (required by modern browsers)
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -days "$DAYS" \
  -sha256 \
  -subj "/C=CH/ST=Zurich/L=Zurich/O=Local Dev/OU=Dev/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1"

# Secure permissions
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"

echo "✅ Created:"
echo "  Key : $KEY_FILE"
echo "  Cert: $CERT_FILE"