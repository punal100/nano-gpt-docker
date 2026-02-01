#!/bin/bash
# Setup Let's Encrypt SSL certificates for production
# Requires: certbot, domain name, ports 80/443 accessible

set -e

echo "=== NanoGPT Shim - Let's Encrypt SSL Setup ==="
echo ""

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Error: certbot is not installed"
    echo ""
    echo "Install certbot:"
    echo "  Ubuntu/Debian: sudo apt-get install certbot"
    echo "  CentOS/RHEL:   sudo yum install certbot"
    echo "  macOS:         brew install certbot"
    echo ""
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Get domain name
if [ -z "$1" ]; then
    read -p "Enter your domain name: " DOMAIN
else
    DOMAIN=$1
fi

if [ -z "$DOMAIN" ]; then
    echo "Error: Domain name is required"
    exit 1
fi

echo ""
echo "Domain: $DOMAIN"
echo ""
echo "Prerequisites:"
echo "  ✓ Domain $DOMAIN must point to this server's IP"
echo "  ✓ Ports 80 and 443 must be accessible from internet"
echo "  ✓ No other service should be using port 80"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 1
fi

# Get email for Let's Encrypt notifications
read -p "Enter email for Let's Encrypt notifications: " EMAIL

if [ -z "$EMAIL" ]; then
    echo "Error: Email is required"
    exit 1
fi

echo ""
echo "Obtaining SSL certificate from Let's Encrypt..."
echo ""

# Stop any running containers that might use port 80
echo "Stopping Docker containers..."
docker compose down 2>/dev/null || true
docker compose -f docker-compose.https.yml down 2>/dev/null || true

# Obtain certificate using standalone mode
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN"

if [ $? -ne 0 ]; then
    echo ""
    echo "Error: Failed to obtain certificate"
    echo "Please check:"
    echo "  1. Domain DNS is correctly configured"
    echo "  2. Ports 80/443 are accessible"
    echo "  3. No firewall blocking connections"
    exit 1
fi

echo ""
echo "✓ Certificate obtained successfully!"
echo ""

# Create nginx ssl directory
mkdir -p nginx/ssl

# Copy certificates
echo "Copying certificates to nginx/ssl/..."
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem nginx/ssl/cert.pem
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem nginx/ssl/key.pem

# Set permissions
chmod 644 nginx/ssl/cert.pem
chmod 600 nginx/ssl/key.pem

echo "✓ Certificates copied"
echo ""

# Update nginx configuration with domain name
if [ -f "nginx/nginx.conf" ]; then
    echo "Updating nginx configuration with domain name..."
    sed -i.bak "s/server_name _;/server_name $DOMAIN;/g" nginx/nginx.conf
    echo "✓ nginx configuration updated"
    echo ""
fi

# Setup auto-renewal cron job
echo "Setting up auto-renewal..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CRON_CMD="0 0 * * * certbot renew --quiet && cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $PROJECT_DIR/nginx/ssl/cert.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $PROJECT_DIR/nginx/ssl/key.pem && cd $PROJECT_DIR && docker compose -f docker-compose.https.yml restart nginx"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "certbot renew"; then
    echo "Auto-renewal cron job already exists"
else
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "✓ Auto-renewal cron job added"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Certificate details:"
echo "  Domain: $DOMAIN"
echo "  Certificate: nginx/ssl/cert.pem"
echo "  Private key: nginx/ssl/key.pem"
echo "  Expires: $(date -d "+90 days" +%Y-%m-%d)"
echo ""
echo "Auto-renewal:"
echo "  ✓ Cron job configured to renew daily"
echo "  ✓ Certificates will auto-renew before expiration"
echo ""
echo "Next steps:"
echo "  1. Start the shim: docker compose -f docker-compose.https.yml up -d"
echo "  2. Test HTTPS: curl https://$DOMAIN/health"
echo "  3. Configure Kilo Code to use: https://$DOMAIN/v1"
echo ""
echo "Test auto-renewal:"
echo "  sudo certbot renew --dry-run"
echo ""
