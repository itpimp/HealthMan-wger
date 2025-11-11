#!/usr/bin/env bash
# HealthMan-wger Initial Setup Script
# Consolidates environment generation, Caddyfile processing, and database migrations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check for required commands
check_requirements() {
    local missing=()
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing+=("docker-compose or docker compose")
    fi
    
    if ! command -v openssl &> /dev/null && ! command -v base64 &> /dev/null; then
        missing+=("openssl or base64")
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required commands: ${missing[*]}${NC}" >&2
        exit 1
    fi
}

# Helper to generate random strings
rand() {
    local len=${1:-32}
    if command -v openssl &> /dev/null; then
        openssl rand -base64 "$len" | tr -d '=+/' | cut -c1-"$len"
    else
        # Fallback using /dev/urandom
        head -c "$len" /dev/urandom | base64 | tr -d '=+/' | cut -c1-"$len"
    fi
}

# Generate environment file
generate_env() {
    local EXAMPLE=.env.example
    local ENV=.env
    
    if [ -f "$ENV" ]; then
        echo -e "${YELLOW}.env already exists. Skipping generation.${NC}"
        echo -e "${YELLOW}To regenerate, delete .env first.${NC}"
        return 0
    fi
    
    if [ ! -f "$EXAMPLE" ]; then
        echo -e "${RED}Error: $EXAMPLE not found.${NC}" >&2
        echo -e "${YELLOW}Creating a basic .env.example template...${NC}"
        cat > "$EXAMPLE" << 'EOF'
# HealthMan-wger Environment Variables
COMPOSE_PROJECT_NAME=healthman
COMPOSE_PROJECT_HUMAN_NAME=HealthMan

# Base Domain Configuration
BASE_DOMAIN=healthman.breyninc.co.za

# Service Domains (auto-configured if BASE_DOMAIN is set)
WGER_DOMAIN=wger.healthman.breyninc.co.za
RECIPES_DOMAIN=recipes.healthman.breyninc.co.za
FLOW_DOMAIN=flow.healthman.breyninc.co.za
DASH_DOMAIN=dash.healthman.breyninc.co.za

# Database
POSTGRES_USER=healthman
POSTGRES_PASSWORD=change_me
POSTGRES_DB=healthman
REDIS_PASSWORD=__REDIS_PASSWORD__

# Wger Configuration
WGER_DEBUG=False
WGER_SECRET_KEY=__WGER_SECRET__
WGER_ALLOWED_HOSTS=localhost,127.0.0.1,wger.healthman.breyninc.co.za

# Tandoor Configuration
TANDOOR_SECRET_KEY=__TANDOOR_SECRET__

# n8n Configuration
N8N_BASIC_AUTH_ACTIVE=true
N8N_USER=admin
N8N_PASSWORD=change_me
N8N_ENCRYPTION_KEY=__N8N_ENCRYPTION_KEY__
N8N_WEBHOOK_URL=https://flow.healthman.breyninc.co.za
N8N_HOST=flow.healthman.breyninc.co.za
N8N_PROTOCOL=https
# CORS Configuration (comma-separated list of allowed origins, or * for all)
N8N_CORS_ORIGIN=*
N8N_WEBHOOK_CORS=true

# Grafana Configuration
GRAFANA_USER=admin
GRAFANA_PASSWORD=change_me
GRAFANA_DOMAIN=dash.healthman.breyninc.co.za

# Caddy Configuration
CADDY_ADMIN_EMAIL=admin@healthman.breyninc.co.za

# SMTP Email Configuration (for wger, Tandoor, Grafana notifications)
# Configure these to enable email notifications
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
SMTP_FROM_EMAIL=your-email@gmail.com

# Timezone
TZ=UTC

# Fail2ban Configuration (optional - set to true to enable fail2ban setup)
ENABLE_FAIL2BAN=false
EOF
        echo -e "${GREEN}Created $EXAMPLE. Please review and customize.${NC}"
    fi
    
    echo -e "${GREEN}Generating .env file...${NC}"
    cp "$EXAMPLE" "$ENV"
    
    # Replace placeholders
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed requires different syntax
        sed -i '' "s|__WGER_SECRET__|$(rand 50)|g" "$ENV"
        sed -i '' "s|__TANDOOR_SECRET__|$(rand 50)|g" "$ENV"
        sed -i '' "s|__N8N_ENCRYPTION_KEY__|$(rand 32)|g" "$ENV"
        sed -i '' "s|__REDIS_PASSWORD__|$(rand 32)|g" "$ENV"
    else
        # Linux sed
        sed -i "s|__WGER_SECRET__|$(rand 50)|g" "$ENV"
        sed -i "s|__TANDOOR_SECRET__|$(rand 50)|g" "$ENV"
        sed -i "s|__N8N_ENCRYPTION_KEY__|$(rand 32)|g" "$ENV"
        sed -i "s|__REDIS_PASSWORD__|$(rand 32)|g" "$ENV"
    fi
    
    echo -e "${GREEN}Created $ENV with generated secrets.${NC}"
    echo -e "${YELLOW}Please review and edit values like CADDY_ADMIN_EMAIL, passwords, and domains.${NC}"
}

# Setup fail2ban (optional)
setup_fail2ban() {
    local ENABLE_FAIL2BAN=${ENABLE_FAIL2BAN:-false}
    
    if [[ "$ENABLE_FAIL2BAN" != "true" ]]; then
        echo -e "${YELLOW}Skipping fail2ban setup (ENABLE_FAIL2BAN not set to true).${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Setting up fail2ban...${NC}"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}Note: fail2ban setup requires root/sudo privileges.${NC}"
        echo -e "${YELLOW}You can set up fail2ban manually later or run this script with sudo.${NC}"
        return 0
    fi
    
    # Check if fail2ban is installed
    if ! command -v fail2ban-client &> /dev/null; then
        echo -e "${YELLOW}Installing fail2ban...${NC}"
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y fail2ban
        elif command -v yum &> /dev/null; then
            yum install -y fail2ban
        elif command -v dnf &> /dev/null; then
            dnf install -y fail2ban
        else
            echo -e "${RED}Package manager not found. Please install fail2ban manually.${NC}" >&2
            return 1
        fi
    fi
    
    # Create n8n webhook filter
    cat > /etc/fail2ban/filter.d/n8n-webhook.conf << 'EOF'
[Definition]
failregex = ^.*"method":"(GET|POST).*"statusCode":(401|403|429).*$
ignoreregex =
EOF
    
    # Create n8n webhook jail
    mkdir -p /etc/fail2ban/jail.d
    
    cat > /etc/fail2ban/jail.d/n8n-webhook.conf << 'EOF'
[n8n-webhook]
enabled = true
port = 80,443
filter = n8n-webhook
logpath = /var/log/caddy/*.log
maxretry = 5
bantime = 3600
findtime = 600
EOF
    
    # Create Caddy log directory if it doesn't exist
    mkdir -p /var/log/caddy
    chmod 755 /var/log/caddy
    
    # Create wger/tandoor filter for failed auth
    cat > /etc/fail2ban/filter.d/healthman-auth.conf << 'EOF'
[Definition]
failregex = ^.*"method":"(GET|POST).*"statusCode":401.*"uri":"/api/.*$
ignoreregex =
EOF
    
    cat > /etc/fail2ban/jail.d/healthman-auth.conf << 'EOF'
[healthman-auth]
enabled = true
port = 80,443
filter = healthman-auth
logpath = /var/log/caddy/*.log
maxretry = 3
bantime = 7200
findtime = 600
EOF
    
    # Start and enable fail2ban
    systemctl enable fail2ban || true
    systemctl restart fail2ban || service fail2ban restart || true
    
    echo -e "${GREEN}fail2ban configured successfully!${NC}"
    echo -e "${YELLOW}Note: Make sure Caddy logs are written to /var/log/caddy/ for fail2ban to work.${NC}"
    echo -e "${YELLOW}You may need to configure Caddy to log to /var/log/caddy/access.log${NC}"
}

# Process Caddyfile from template
process_caddyfile() {
    local TEMPLATE="docker_configs/caddy/Caddyfile.template"
    local OUTPUT="docker_configs/caddy/Caddyfile"
    
    if [ ! -f "$TEMPLATE" ]; then
        echo -e "${YELLOW}Caddyfile template not found. Skipping Caddyfile generation.${NC}"
        return 0
    fi
    
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}.env file not found. Skipping Caddyfile generation.${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Processing Caddyfile from template...${NC}"
    
    # Load environment variables
    set -a
    source .env
    set +a
    
    # Default values - using healthman.breyninc.co.za as base domain
    BASE_DOMAIN=${BASE_DOMAIN:-healthman.breyninc.co.za}
    WGER_DOMAIN=${WGER_DOMAIN:-wger.${BASE_DOMAIN}}
    RECIPES_DOMAIN=${RECIPES_DOMAIN:-recipes.${BASE_DOMAIN}}
    FLOW_DOMAIN=${FLOW_DOMAIN:-flow.${BASE_DOMAIN}}
    DASH_DOMAIN=${DASH_DOMAIN:-dash.${BASE_DOMAIN}}
    CADDY_ADMIN_EMAIL=${CADDY_ADMIN_EMAIL:-admin@${BASE_DOMAIN}}
    
    # Export for envsubst
    export WGER_DOMAIN RECIPES_DOMAIN FLOW_DOMAIN DASH_DOMAIN CADDY_ADMIN_EMAIL
    
    # Check if envsubst is available
    if command -v envsubst &> /dev/null; then
        envsubst < "$TEMPLATE" > "$OUTPUT"
        echo -e "${GREEN}Caddyfile generated at $OUTPUT${NC}"
        echo -e "${GREEN}Domains configured:${NC}"
        echo -e "  - Wger: ${WGER_DOMAIN}"
        echo -e "  - Recipes: ${RECIPES_DOMAIN}"
        echo -e "  - Flow (n8n): ${FLOW_DOMAIN}"
        echo -e "  - Dash (Grafana): ${DASH_DOMAIN}"
    else
        echo -e "${YELLOW}envsubst not found. Please manually update Caddyfile from template.${NC}"
    fi
}

# Apply database migrations
apply_migrations() {
    local CONTAINER_NAME="${COMPOSE_PROJECT_NAME:-HealthMan}_wger"
    
    echo -e "${GREEN}Checking if wger container is running...${NC}"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}Wger container not running. Starting services...${NC}"
        if docker compose version &> /dev/null; then
            docker compose up -d wger
        else
            docker-compose up -d wger
        fi
        
        echo -e "${YELLOW}Waiting for wger to be ready...${NC}"
        sleep 10
    fi
    
    echo -e "${GREEN}Applying migrations for fasting_extension...${NC}"
    
    # Wait for container to be ready
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec "$CONTAINER_NAME" python manage.py check --database default &> /dev/null; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo -e "${RED}Error: wger container not responding.${NC}" >&2
        return 1
    fi
    
    docker exec "$CONTAINER_NAME" python manage.py makemigrations fasting_extension || true
    docker exec "$CONTAINER_NAME" python manage.py migrate
    
    echo -e "${GREEN}Migrations completed!${NC}"
}

# Main function
main() {
    echo -e "${GREEN}=== HealthMan-wger Initial Setup ===${NC}"
    echo ""
    
    check_requirements
    generate_env
    
    echo ""
    echo -e "${GREEN}Environment file ready.${NC}"
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Review and edit .env file with your configuration"
    echo "  2. Run: docker compose up -d"
    echo "  3. Run: bash initial_setup.sh --migrate (after containers are up)"
    echo ""
    
    if [[ "${1:-}" == "--migrate" ]] || [[ "${1:-}" == "--full" ]]; then
        process_caddyfile
        if [[ "${1:-}" == "--full" ]]; then
            apply_migrations
            # Load .env to check ENABLE_FAIL2BAN
            if [ -f ".env" ]; then
                set -a
                source .env
                set +a
                if [[ "${ENABLE_FAIL2BAN:-false}" == "true" ]]; then
                    setup_fail2ban
                fi
            fi
        fi
    elif [[ "${1:-}" == "--migrate-only" ]]; then
        apply_migrations
    elif [[ "${1:-}" == "--caddy-only" ]]; then
        process_caddyfile
    elif [[ "${1:-}" == "--fail2ban" ]]; then
        if [ -f ".env" ]; then
            set -a
            source .env
            set +a
        fi
        setup_fail2ban
    else
        echo -e "${YELLOW}Optional flags:${NC}"
        echo "  --full         : Generate env, process Caddyfile, run migrations, and setup fail2ban (if enabled)"
        echo "  --migrate      : Process Caddyfile and run migrations"
        echo "  --migrate-only : Only run database migrations"
        echo "  --caddy-only   : Only process Caddyfile template"
        echo "  --fail2ban     : Setup fail2ban (requires ENABLE_FAIL2BAN=true in .env)"
    fi
}

# Run main function
main "$@"

