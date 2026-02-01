#!/bin/bash
# Generate self-signed SSL certificates for development/testing
# WARNING: Self-signed certificates will show security warnings in browsers
# For production, use Let's Encrypt or commercial certificates

set -e

echo "=== NanoGPT Shim - Self-Signed SSL Certificate Generator ==="
echo ""
echo "This script generates self-signed SSL certificates for development/testing."
echo "WARNING: These certificates will show security warnings in browsers."
echo "For production, use Let's Encrypt (see scripts/setup-letsencrypt.sh)"
echo ""

# Create ssl directory if it doesn't exist
mkdir -p nginx/ssl

# Prompt for certificate details
read -p "Country Code (2 letters) [US]: " COUNTRY
COUNTRY=${COUNTRY:-US}

read -p "State/Province [California]: " STATE
STATE=${STATE:-California}

read -p "City [San Francisco]: " CITY
CITY=${CITY:-San Francisco}

read -p "Organization [My Company]: " ORG
ORG=${ORG:-My Company}

read -p "Common Name (domain) [localhost]: " CN
CN=${CN:-localhost}

echo ""
echo "Generating self-signed certificate..."
echo "Country: $COUNTRY"
echo "State: $STATE"
echo "City: $CITY"
echo "Organization: $ORG"
echo "Common Name: $CN"
echo ""

# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/CN=$CN"

# Set appropriate permissions
chmod 600 nginx/ssl/key.pem
chmod 644 nginx/ssl/cert.pem

echo ""
echo "✓ SSL certificates generated successfully!"
echo ""
echo "Files created:"
echo "  - nginx/ssl/cert.pem (certificate)"
echo "  - nginx/ssl/key.pem (private key)"
echo ""
echo "Next steps:"
echo "  1. Deploy with HTTPS: docker compose -f docker-compose.https.yml up -d"
echo "  2. Access at: https://$CN"
echo ""
echo "Note: Your browser will show a security warning because this is a self-signed certificate."
echo "You can safely proceed for development/testing purposes."
echo ""
