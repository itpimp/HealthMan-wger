#!/usr/bin/env bash
# Script to update SMTP settings after initial setup
# This allows you to modify email configuration without regenerating the entire .env file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Run initial_setup.sh first." >&2
    exit 1
fi

echo "=== SMTP Email Configuration Update ==="
echo ""
echo "Current SMTP settings from .env:"
grep "^SMTP_" "$ENV_FILE" || echo "No SMTP settings found"
echo ""

read -p "SMTP Host (e.g., smtp.gmail.com): " SMTP_HOST
read -p "SMTP Port (587 for TLS, 465 for SSL, 25 for unencrypted) [587]: " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-587}

read -p "SMTP Username/Email: " SMTP_USER
read -sp "SMTP Password: " SMTP_PASSWORD
echo ""

read -p "Use TLS? (y/n) [y]: " USE_TLS
USE_TLS=${USE_TLS:-y}
if [[ "$USE_TLS" =~ ^[Yy] ]]; then
    SMTP_USE_TLS="true"
    SMTP_USE_SSL="false"
else
    SMTP_USE_TLS="false"
    read -p "Use SSL? (y/n) [n]: " USE_SSL
    USE_SSL=${USE_SSL:-n}
    if [[ "$USE_SSL" =~ ^[Yy] ]]; then
        SMTP_USE_SSL="true"
    else
        SMTP_USE_SSL="false"
    fi
fi

read -p "From Email Address: " SMTP_FROM_EMAIL

# Update or add SMTP settings in .env
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed
    sed -i '' "/^SMTP_HOST=/d; /^SMTP_PORT=/d; /^SMTP_USER=/d; /^SMTP_PASSWORD=/d; /^SMTP_USE_TLS=/d; /^SMTP_USE_SSL=/d; /^SMTP_FROM_EMAIL=/d" "$ENV_FILE"
else
    # Linux sed
    sed -i "/^SMTP_HOST=/d; /^SMTP_PORT=/d; /^SMTP_USER=/d; /^SMTP_PASSWORD=/d; /^SMTP_USE_TLS=/d; /^SMTP_USE_SSL=/d; /^SMTP_FROM_EMAIL=/d" "$ENV_FILE"
fi

# Append new SMTP settings
cat >> "$ENV_FILE" << EOF

# SMTP Email Configuration
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD
SMTP_USE_TLS=$SMTP_USE_TLS
SMTP_USE_SSL=$SMTP_USE_SSL
SMTP_FROM_EMAIL=$SMTP_FROM_EMAIL
EOF

echo ""
echo "SMTP settings updated in .env file."
echo "Restart affected services to apply changes:"
echo "  docker compose restart wger tandoor grafana"
echo ""

