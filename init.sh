#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Inception Project Initialization${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
USERNAME="nabbas"
DATA_DIR="/home/$USERNAME/data"
DOMAIN="nabbas.42.fr"

# Step 1: Create secrets directory
echo -e "${YELLOW}[1/5]${NC} Creating secrets directory..."
mkdir -p secrets

# Step 2: Create secret files
echo -e "${YELLOW}[2/5]${NC} Creating secret files..."

# Database password
echo -n "admin" > secrets/db_password.txt
chmod 600 secrets/db_password.txt
echo -e "  ${GREEN}✓${NC} Created secrets/db_password.txt"

# Database root password
echo -n "admin" > secrets/db_root_password.txt
chmod 600 secrets/db_root_password.txt
echo -e "  ${GREEN}✓${NC} Created secrets/db_root_password.txt"

# Step 3: Create .env file
echo -e "${YELLOW}[3/5]${NC} Creating .env file..."
cat > srcs/.env << 'EOF'
# General
# DOMAIN_NAME=localhost	# change this to nabbas.42.fr
DOMAIN_NAME=nabbas.42.fr

# MariaDB
MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db_root_password
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PASSWORD_FILE=/run/secrets/db_password

# WordPress
WP_DB_HOST=mariadb:3306
WP_DB_NAME=wordpress
WP_DB_USER=wp_user
WP_DB_PASSWORD_FILE=/run/secrets/db_password
WP_TABLE_PREFIX=wp_
WP_URL=https://${DOMAIN_NAME}
WP_TITLE="Inception Site"

# WordPress Admin User
WP_ADMIN_USER=nathan   # not 'admin', 'administrator', etc.
WP_ADMIN_PASSWORD=nathan
WP_ADMIN_EMAIL=nataneabbas@gmail.com

# WordPress Second User (non-admin)
WP_USER_NAME=wpuser
WP_USER_PASSWORD=wpuser123
WP_USER_EMAIL=wpuser@nabbas.42.fr
EOF
chmod 644 srcs/.env
echo -e "  ${GREEN}✓${NC} Created srcs/.env"

# Step 4: Create data directories
echo -e "${YELLOW}[4/5]${NC} Creating data directories..."
sudo mkdir -p "$DATA_DIR/mariadb" "$DATA_DIR/wordpress"
sudo chown -R $USER:$USER "$DATA_DIR"
echo -e "  ${GREEN}✓${NC} Created $DATA_DIR/mariadb"
echo -e "  ${GREEN}✓${NC} Created $DATA_DIR/wordpress"

# Step 5: Add domain to /etc/hosts if not already present
echo -e "${YELLOW}[5/5]${NC} Configuring /etc/hosts..."
if ! grep -q "$DOMAIN" /etc/hosts; then
    echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    echo -e "  ${GREEN}✓${NC} Added $DOMAIN to /etc/hosts"
else
    echo -e "  ${GREEN}✓${NC} $DOMAIN already in /etc/hosts"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Initialization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Configuration summary:"
echo -e "  - Domain: ${GREEN}$DOMAIN${NC}"
echo -e "  - Data directory: ${GREEN}$DATA_DIR${NC}"
echo -e "  - Secrets: ${GREEN}secrets/${NC}"
echo -e "  - Environment: ${GREEN}srcs/.env${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Run: ${YELLOW}make up${NC} (or ${YELLOW}sudo docker compose -f srcs/docker-compose.yml up -d --build${NC})"
echo -e "  2. Wait for containers to start (~30 seconds)"
echo -e "  3. Access: ${GREEN}https://$DOMAIN${NC}"
echo -e "  4. Login with: ${YELLOW}nathan / nathan${NC}"
echo ""