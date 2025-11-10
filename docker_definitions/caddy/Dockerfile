# Caddy reverse proxy with caddy-security module
FROM caddy:builder AS builder

# Build Caddy with caddy-security module
RUN xcaddy build \
    --with github.com/greenpau/caddy-security@latest

FROM caddy:latest

# Copy the custom-built Caddy binary
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# Caddyfile is provided via volume mount
# caddy-security configuration can be added to Caddyfile for:
# - Rate limiting
# - JWT authentication
# - IP filtering
# - Bot protection
# - Authentication portal

USER caddy

