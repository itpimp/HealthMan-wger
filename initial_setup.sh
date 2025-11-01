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
COMPOSE_PROJECT_NAME=HealthMan
POSTGRES_USER=healthman
POSTGRES_PASSWORD=change_me
POSTGRES_DB=healthman
REDIS_PASSWORD=__REDIS_PASSWORD__
WGER_DEBUG=False
WGER_SECRET_KEY=__WGER_SECRET__
WGER_ALLOWED_HOSTS=localhost,127.0.0.1
TANDOOR_SECRET_KEY=__TANDOOR_SECRET__
N8N_BASIC_AUTH_ACTIVE=true
N8N_USER=admin
N8N_PASSWORD=change_me
N8N_ENCRYPTION_KEY=__N8N_ENCRYPTION_KEY__
N8N_WEBHOOK_URL=http://localhost:5678
N8N_HOST=localhost
N8N_PROTOCOL=http
GRAFANA_USER=admin
GRAFANA_PASSWORD=change_me
GRAFANA_DOMAIN=localhost
CADDY_ADMIN_EMAIL=admin@example.com
TZ=UTC
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
    
    # Default values
    WGER_DOMAIN=${WGER_DOMAIN:-wger.example.com}
    TANDOOR_DOMAIN=${TANDOOR_DOMAIN:-tandoor.example.com}
    N8N_DOMAIN=${N8N_DOMAIN:-n8n.example.com}
    GRAFANA_DOMAIN=${GRAFANA_DOMAIN:-grafana.example.com}
    CADDY_ADMIN_EMAIL=${CADDY_ADMIN_EMAIL:-admin@example.com}
    
    # Check if envsubst is available
    if command -v envsubst &> /dev/null; then
        envsubst < "$TEMPLATE" > "$OUTPUT"
        echo -e "${GREEN}Caddyfile generated at $OUTPUT${NC}"
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
        fi
    elif [[ "${1:-}" == "--migrate-only" ]]; then
        apply_migrations
    elif [[ "${1:-}" == "--caddy-only" ]]; then
        process_caddyfile
    else
        echo -e "${YELLOW}Optional flags:${NC}"
        echo "  --full         : Generate env, process Caddyfile, and run migrations"
        echo "  --migrate      : Process Caddyfile and run migrations"
        echo "  --migrate-only : Only run database migrations"
        echo "  --caddy-only   : Only process Caddyfile template"
    fi
}

# Run main function
main "$@"

