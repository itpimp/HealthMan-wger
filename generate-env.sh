#!/usr/bin/env bash
set -euo pipefail


EXAMPLE=.env.example
ENV=.env


if [ -f "$ENV" ]; then
echo ".env already exists. If you want to regenerate, move or remove the existing .env first." >&2
exit 0
fi


if [ ! -f "$EXAMPLE" ]; then
echo "Missing $EXAMPLE" >&2
exit 1
fi


cp $EXAMPLE $ENV


# helper to generate random strings
rand() {
local len=${1:-32}
# base64 shines
openssl rand -base64 $len | tr -d '=+/
' | cut -c1-$len
}


# replace placeholders
sed -i "s|__WGER_SECRET__|$(rand 50)|g" $ENV
sed -i "s|__TANDOOR_SECRET__|$(rand 50)|g" $ENV
sed -i "s|__N8N_ENCRYPTION_KEY__|$(rand 32)|g" $ENV
sed -i "s|__WGER_API_TOKEN__|$(rand 40)|g" $ENV
sed -i "s|__TANDOOR_API_KEY__|$(rand 40)|g" $ENV


# show summary
echo "Created $ENV. Please review and edit values like CADDY_ADMIN_EMAIL and host ports if necessary."