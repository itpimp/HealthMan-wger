# HealthMan-wger

A self-hosted health tracking and planning environment, using mature, open-source, self-hosted tools.

## Overview

HealthMan-wger integrates multiple open-source health and fitness applications into a unified, self-hosted stack:

- **[wger](https://github.com/wger-project/wger)** - Workout and exercise tracking with custom fasting extension accessible through Telegram instant messenger
- **[Tandoor Recipes](https://github.com/vabene1111/recipes)** - Recipe management and meal planning
- **[n8n](https://github.com/n8n-io/n8n)** - Workflow automation for health data synchronization
- **[Grafana](https://github.com/grafana/grafana)** - Health metrics visualization and dashboards
- **[Caddy](https://github.com/caddyserver/caddy)** - Reverse proxy with automatic HTTPS

## Project Structure

```
HealthMan-wger/
├── docker-compose.yml       # Main orchestration file
├── initial_setup.sh         # Consolidated setup script
├── update_smtp.sh           # SMTP configuration update script
├── docker_definitions/      # Docker build definitions
│   ├── wger/
│   │   └── Dockerfile       # Custom wger image with extensions
│   ├── tandoor/
│   │   └── Dockerfile       # Custom Tandoor image
│   ├── postgres/
│   │   └── Dockerfile       # PostgreSQL with optimizations
│   ├── redis/
│   │   └── Dockerfile       # Redis configuration
│   ├── n8n/
│   │   └── Dockerfile       # n8n workflow automation
│   ├── grafana/
│   │   └── Dockerfile       # Grafana with provisioning
│   └── caddy/
│       └── Dockerfile       # Caddy reverse proxy
├── docker_configs/          # Configuration and customization files
│   ├── caddy/              # Caddy reverse proxy config
│   │   ├── Caddyfile       # Active Caddyfile (generated from template)
│   │   └── Caddyfile.template  # Template for domain customization
│   ├── wger_extensions/     # Custom wger extensions
│   │   └── fasting_extension/  # Fasting tracking extension
│   │       ├── __init__.py
│   │       ├── api.py       # REST API views
│   │       ├── apps.py      # Django app configuration
│   │       ├── models.py    # FastSession model
│   │       ├── serializers.py  # API serializers
│   │       ├── urls.py      # URL routing
│   │       └── wger_overrides/
│   │           ├── settings_extra.py  # Django settings extension
│   │           └── urls_extra.py      # URL pattern extension
│   ├── grafana/            # Grafana provisioning configs
│   │   └── provisioning/
│   │       ├── dashboards/ # Dashboard definitions
│   │       │   └── health_dashboard.json
│   │       └── datasources/ # Data source configurations
│   │           └── datasource.yaml
│   └── n8n_workflows/       # n8n automation workflows
│       ├── daily_summary_telegram.json
│       ├── fasting_log_webhook.json
│       └── tandoor_to_wger_sync.json
├── docker_data/            # Persistent data storage (gitignored)
│   ├── postgres/           # PostgreSQL database files
│   ├── redis/              # Redis data files
│   ├── wger/               # wger application data
│   ├── tandoor/            # Tandoor media files
│   ├── n8n/                # n8n workflow data
│   ├── grafana/            # Grafana configuration
│   └── caddy/              # Caddy certificates and data
└── README.md
```

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- OpenSSL or base64 (for secret generation)
- Basic understanding of Docker and environment variables

**Note:** This setup is optimized for WSL2 and Proxmox LXC containers. See WSL/LXC Compatibility section below.

### Installation

1. **Clone the repository** (if applicable) or navigate to the project directory

2. **Run initial setup**:
   ```bash
   bash initial_setup.sh
   ```
   
   This will:
   - Generate `.env` file with secure random secrets
   - Process Caddyfile template (if using custom domains)
   - Set up the environment

3. **Edit `.env` file**:
   - Set `CADDY_ADMIN_EMAIL` for SSL certificate generation
   - Configure domain names or use `localhost` for local development
   - Set database passwords and API tokens
   - Configure n8n and Grafana credentials
   - Set n8n webhook URLs if using subdomains
   - **Configure SMTP settings** (optional, for email notifications):
     - Edit `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`
     - Or run `bash update_smtp.sh` after initial setup
   - **Enable fail2ban** (optional, for internet exposure):
     - Set `ENABLE_FAIL2BAN=true` in `.env`
     - Run `bash initial_setup.sh --fail2ban` (requires sudo/root)

4. **Start services**:
   ```bash
   docker compose up -d
   ```
   
   Or if using older docker-compose:
   ```bash
   docker-compose up -d
   ```

5. **Run migrations** (first time only):
   ```bash
   bash initial_setup.sh --migrate-only
   ```
   
   Or for full setup (env + Caddyfile + migrations + fail2ban if enabled):
   ```bash
   bash initial_setup.sh --full
   ```
   
   **Note**: A `.env.example` file is included in the repository for reference.

### Configuration

#### Environment Variables

Key environment variables (set in `.env` file):

**Database:**
- `POSTGRES_USER` - PostgreSQL username
- `POSTGRES_PASSWORD` - PostgreSQL password
- `POSTGRES_DB` - Database name
- `REDIS_PASSWORD` - Redis password

**wger:**
- `WGER_SECRET_KEY` - Django secret key (auto-generated)
- `WGER_DEBUG` - Debug mode (True/False)
- `WGER_ALLOWED_HOSTS` - Comma-separated list of allowed hosts

**n8n:**
- `N8N_BASIC_AUTH_ACTIVE` - Enable basic auth (true/false)
- `N8N_USER` - Basic auth username
- `N8N_PASSWORD` - Basic auth password
- `N8N_WEBHOOK_URL` - Base URL for webhooks (e.g., `https://n8n.example.com`)
- `N8N_HOST` - n8n hostname
- `N8N_PROTOCOL` - Protocol (https for SSL, http for localhost)
- `N8N_EDITOR_BASE_URL` - Optional: Custom editor URL
- `N8N_CORS_ORIGIN` - CORS allowed origins (comma-separated, or `*` for all, default: `*`)
- `N8N_WEBHOOK_CORS` - Enable CORS for webhooks (true/false, default: true)

**Caddy:**
- `CADDY_ADMIN_EMAIL` - Email for Let's Encrypt certificates

**Email/SMTP Configuration (for wger, Tandoor, Grafana):**
- `SMTP_HOST` - SMTP server hostname (e.g., `smtp.gmail.com`)
- `SMTP_PORT` - SMTP port (typically `587` for TLS, `465` for SSL, `25` for unencrypted)
- `SMTP_USER` - SMTP username/email address
- `SMTP_PASSWORD` - SMTP password or app password
- `SMTP_USE_TLS` - Use TLS encryption (true/false, default: true)
- `SMTP_USE_SSL` - Use SSL encryption (true/false, default: false)
- `SMTP_FROM_EMAIL` - From email address for outgoing emails

**Domains (for Caddyfile):**
- `BASE_DOMAIN` - Base domain (e.g., `healthman.breyninc.co.za`)
- `WGER_DOMAIN` - wger subdomain (default: `wger.${BASE_DOMAIN}`)
- `RECIPES_DOMAIN` - Tandoor recipes subdomain (default: `recipes.${BASE_DOMAIN}`)
- `FLOW_DOMAIN` - n8n workflow subdomain (default: `flow.${BASE_DOMAIN}`)
- `DASH_DOMAIN` - Grafana dashboard subdomain (default: `dash.${BASE_DOMAIN}`)
- Configure in `.env` file and use `bash initial_setup.sh --caddy-only` to generate Caddyfile from template

#### SSL and Subdomain Setup

**For Production (with SSL):**
1. Set `N8N_PROTOCOL=https` in `.env`
2. Configure `N8N_WEBHOOK_URL=https://n8n.yourdomain.com`
3. Update Caddyfile with your domain names
4. Ensure DNS records point to your server
5. Caddy will automatically obtain SSL certificates

**For Localhost/Development:**
1. Set `N8N_PROTOCOL=http` in `.env`
2. Set `N8N_WEBHOOK_URL=http://localhost:5678`
3. Update Caddyfile to use `localhost` or remove Caddy and access services directly via exposed ports

#### Custom wger Extension

The `fasting_extension` adds fasting session tracking to wger:

- API endpoint: `/api/v2/fasts/`
- Model: `FastSession` with start/end times, duration, and notes
- Automatically calculates duration in hours

To use the extension:
1. The Dockerfile automatically includes it in the wger image
2. Run migrations: `bash initial_setup.sh --migrate-only`
3. Access via REST API with authentication

#### n8n Workflows

Pre-configured workflows in `docker_configs/n8n_workflows/`:

- **fasting_log_webhook.json** - Webhook to log fasting sessions to wger
- **tandoor_to_wger_sync.json** - Sync recipes from Tandoor to wger meal plans
- **daily_summary_telegram.json** - Daily health summary via Telegram

##### Configuring n8n Workflow Credentials

After importing workflows, you need to configure credentials:

1. **Access n8n**: Navigate to your n8n instance (e.g., `https://flow.healthman.breyninc.co.za`)

2. **Open a workflow**: Click on any workflow to open it

3. **Configure HTTP Basic Auth for wger/Tandoor**:
   - Click on a node that requires authentication (e.g., "Add Note to Wger")
   - Click on the **Credentials** field
   - Select **Create New** or use existing credentials
   - Choose **HTTP Basic Auth**
   - Enter:
     - **Username**: Your wger/Tandoor username
     - **Password**: Your wger/Tandoor API token (found in user settings)
   - Click **Save**

4. **Configure Telegram credentials**:
   - Click on the Telegram node (e.g., "Send Telegram")
   - Click on the **Credentials** field
   - Select **Create New** or use existing credentials
   - Choose **Telegram**
   - Enter your **Telegram Bot Token** (obtained from [@BotFather](https://t.me/botfather))
   - Click **Save**

5. **Set environment variables** (if workflow uses `$env` variables):
   - Go to **Settings** → **Environment Variables**
   - Add:
     - `WGER_USER` - Your wger username
     - `WGER_API_TOKEN` - Your wger API token
     - `TELEGRAM_CHAT_ID` - Your Telegram chat ID
     - `TELEGRAM_BOT_TOKEN` - Your Telegram bot token

6. **Activate workflow**: Toggle the workflow to active (top right)

**Note:** Each workflow may require different credentials. Check the workflow nodes to see which credentials are needed.

#### Telegram Bot Setup

To use Telegram notifications in n8n workflows, you need to create a Telegram bot:

1. **Create a Bot via BotFather**:
   - Open Telegram and search for [@BotFather](https://t.me/botfather)
   - Send the command `/newbot`
   - Follow the prompts to choose a name and username for your bot
   - BotFather will provide you with a **Bot Token** (save this securely)

2. **Get Your Chat ID**:
   - Start a conversation with your new bot on Telegram
   - Send any message to your bot
   - Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Look for `"chat":{"id":123456789}` in the response - this is your Chat ID
   - Alternatively, use [@userinfobot](https://t.me/userinfobot) to get your Chat ID directly

3. **Configure in n8n**:
   - Add `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` to your n8n environment variables
   - Or configure directly in workflow Telegram nodes using n8n's credential system

4. **Official Documentation**:
   - For more details, see [Telegram Bot API Documentation](https://core.telegram.org/bots/api)

**Security Note:** Never share your bot token publicly. Keep it secure in your `.env` file or n8n credentials.

#### Email/SMTP Configuration

Several services (wger, Tandoor, Grafana) can send email notifications. Configure SMTP settings to enable this functionality.

##### Initial Setup

SMTP settings are included in the `.env` file generated by `initial_setup.sh`:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
SMTP_FROM_EMAIL=your-email@gmail.com
```

##### Updating SMTP Settings

To update SMTP configuration after initial setup:

1. **Method 1: Use the update script**:
   ```bash
   bash update_smtp.sh
   ```
   This interactive script will guide you through updating SMTP settings.

2. **Method 2: Manual edit**:
   - Edit `.env` file directly
   - Update the `SMTP_*` variables
   - Restart affected services:
     ```bash
     docker compose restart wger tandoor grafana
     ```

##### Gmail Configuration Example

For Gmail, you need to use an App Password (not your regular password):

1. Enable 2-Step Verification in your Google Account
2. Go to [Google Account → Security → App passwords](https://myaccount.google.com/apppasswords)
3. Generate an app password for "Mail"
4. Use this app password as `SMTP_PASSWORD` in your `.env` file

**Gmail SMTP Settings:**
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=<app-password>
SMTP_USE_TLS=true
SMTP_USE_SSL=false
SMTP_FROM_EMAIL=your-email@gmail.com
```

##### Other Email Providers

**Outlook/Office365:**
```
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_USE_TLS=true
```

**SendGrid:**
```
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=<sendgrid-api-key>
SMTP_USE_TLS=true
```

**Custom SMTP Server:**
- Contact your email provider for SMTP settings
- Common ports: `587` (TLS), `465` (SSL), `25` (unencrypted, not recommended)

##### Services Using Email

- **wger**: User registration emails, password resets, workout reminders
- **Tandoor**: Recipe sharing, meal plan notifications
- **Grafana**: Alert notifications, dashboard sharing

**Note:** If SMTP is not configured, email features will be disabled in these services. Services will continue to function normally without email notifications.

#### n8n CORS Configuration

For n8n webhooks to work properly from external domains (e.g., mobile apps, external websites), CORS must be configured:

1. **Allow all origins** (development/testing):
   ```bash
   N8N_CORS_ORIGIN=*
   N8N_WEBHOOK_CORS=true
   ```

2. **Restrict to specific domains** (production recommended):
   ```bash
   N8N_CORS_ORIGIN=https://app.example.com,https://mobile.example.com
   N8N_WEBHOOK_CORS=true
   ```

3. **After updating**:
   ```bash
   docker compose restart n8n
   ```

**Security Note:** Using `*` allows any origin. For production, specify exact domains.

### Accessing Services

After starting services, access them via:

- **wger**: `http://wger.example.com` or `http://localhost` (via Caddy)
- **Tandoor**: `http://tandoor.example.com` or `http://localhost:8081` (direct)
- **n8n**: `http://n8n.example.com` or `http://localhost:5678` (direct)
- **Grafana**: `http://grafana.example.com` or `http://localhost:3000` (direct)

Default credentials are set in your `.env` file.

### Mobile Applications

Both wger and Tandoor have official Android applications available:

#### wger Workout Manager
- **Android App**: [wger Workout Manager on Google Play](https://play.google.com/store/search?q=wger&c=apps)
- **Developer**: Roland Geider
- Connect the app to your self-hosted wger instance by configuring the server URL in the app settings.

#### Tandoor Recipes - kitshn
- **Android App**: [kitshn (for Tandoor) on Google Play](https://play.google.com/store/apps/details?id=de.kitshn.android)
- **Developer**: Aimo K.
- Features include:
  - Recipe management with markdown support
  - Meal planning
  - Shopping lists with offline mode
  - Recipe books and favorites
  - Built with Material You design
- Connect to your self-hosted Tandoor instance by entering your server URL in the app settings.

## Customization

### Adding New Extensions

1. Place extension code in `docker_configs/wger_extensions/`
2. Update `docker_definitions/wger/Dockerfile` to copy the extension
3. Update `docker_configs/wger_extensions/fasting_extension/wger_overrides/settings_extra.py`
4. Rebuild: `docker compose build wger`
5. Run migrations if needed: `bash initial_setup.sh --migrate-only`

### Custom n8n Workflows

1. Create workflows in n8n UI
2. Export and save to `docker_configs/n8n_workflows/`
3. Workflows are automatically available in n8n

### Grafana Dashboards

1. Add dashboard JSON files to `docker_configs/grafana/provisioning/dashboards/`
2. Restart Grafana: `docker-compose restart grafana`

## Maintenance

### Backup

Backup `docker_data/` directory regularly:

```bash
tar -czf healthman-backup-$(date +%Y%m%d).tar.gz docker_data/
```

### Updates

1. Pull latest images: `docker-compose pull`
2. Rebuild custom services: `docker-compose build`
3. Restart: `docker-compose up -d`

### Logs

View logs for any service:

```bash
docker compose logs -f [service-name]
```

Or with older docker-compose:
```bash
docker-compose logs -f [service-name]
```

## WSL/LXC Compatibility

This setup includes optimizations for WSL2 and Proxmox LXC containers:

### WSL2 Specific Adjustments
- **Shared Memory**: PostgreSQL uses `shm_size` and tmpfs for /tmp to handle WSL2's shared memory limitations
- **Network**: Uses bridge networking with fallback options for host mode if needed
- **File Permissions**: Docker handles permissions automatically

### Proxmox LXC Adjustments
- **Memory Limits**: PostgreSQL configured with shared memory workarounds
- **Resource Constraints**: Services configured to work within LXC resource limits
- **Network**: Bridge networking with optional host mode fallback

### Troubleshooting WSL/LXC Issues

**If PostgreSQL fails to start:**
- Uncomment `network_mode: host` in postgres service (test one service at a time)
- Or uncomment `driver: host` in networks section

**If experiencing network connectivity issues:**
- Check firewall rules in LXC container
- Verify Docker bridge network is functioning: `docker network inspect healthnet`
- Consider using host network mode for specific services

**Memory issues:**
- Reduce Grafana memory limit in docker-compose.yml if needed
- Monitor with `docker stats`

**File permission issues in WSL:**
- Ensure Docker Desktop WSL integration is enabled
- Check file ownership in `docker_data/` directories

## Troubleshooting

### n8n Webhooks Not Working

- Verify `N8N_WEBHOOK_URL` matches your actual n8n URL
- Check `N8N_PROTOCOL` matches your setup (https vs http)
- Ensure n8n is accessible from the network/webhook source
- For WSL: Use `localhost` instead of container names for webhooks

### SSL Certificate Issues

- Verify `CADDY_ADMIN_EMAIL` is set correctly
- Check DNS records point to your server
- Review Caddy logs: `docker compose logs caddy`

### Migration Errors

- Ensure PostgreSQL is running: `docker compose ps postgres`
- Check wger container logs: `docker compose logs wger`
- Verify volume mounts are correct
- In WSL: Ensure Docker Desktop WSL integration is enabled

## Web Application Firewall (WAF) Recommendations

If exposing this system to the internet, implementing a WAF is strongly recommended to protect against common web attacks.

### Recommended WAF Solutions

#### 1. **Caddy Security Plugin** (Recommended - Integrated with Caddy)

Since you're already using Caddy as a reverse proxy, the easiest integration is using Caddy's security features:

**Option A: Caddy Security Module**
- **GitHub**: [caddy-security](https://github.com/greenpau/caddy-security)
- **Features**: Rate limiting, JWT authentication, IP filtering, bot protection
- **Setup**: Extend Caddy Dockerfile to include the module

**Option B: Caddy with fail2ban Integration**
- Use Caddy's logging combined with fail2ban for automatic IP blocking
- Monitor access logs and automatically ban suspicious IPs

#### 2. **ModSecurity with Caddy**

ModSecurity is a powerful open-source WAF that can be integrated with Caddy:

- **GitHub**: [ModSecurity](https://github.com/SpiderLabs/ModSecurity)
- **Caddy Module**: [caddy-modsecurity](https://github.com/jc21/caddy-modsecurity)
- **Features**: OWASP Core Rule Set, SQL injection protection, XSS protection
- **Setup**: Requires extending Caddy Dockerfile to build with ModSecurity module

#### 3. **Cloudflare** (Cloud-Based, Easiest)

If you're using Cloudflare for DNS, their free tier includes WAF:

- **Setup**: Point your DNS to Cloudflare
- **Features**: DDoS protection, WAF rules, rate limiting (free tier limited)
- **Pros**: Easy setup, no server-side configuration, DDoS protection included
- **Cons**: Cloud-based, requires using Cloudflare DNS

**Configuration:**
1. Move DNS to Cloudflare
2. Enable "Proxy" (orange cloud) for your subdomains
3. Enable WAF rules in Cloudflare dashboard
4. Configure rate limiting rules

#### 4. **Fail2ban** (Server-Level Protection)

Fail2ban monitors logs and automatically bans IPs showing malicious behavior:

- **GitHub**: [Fail2ban](https://github.com/fail2ban/fail2ban)
- **Features**: Automatic IP banning, email notifications, custom filters
- **Best for**: Protecting SSH, HTTP authentication, API endpoints

**Basic Setup (Manual):**
```bash
# Install fail2ban
sudo apt-get install fail2ban

# Configure for n8n/webhooks
# Create /etc/fail2ban/filter.d/n8n-webhook.conf
# Create /etc/fail2ban/jail.d/n8n-webhook.conf
```

**Automated Setup (via initial_setup.sh):**
1. Set `ENABLE_FAIL2BAN=true` in `.env` file
2. Run: `sudo bash initial_setup.sh --fail2ban` (requires sudo/root)
3. Or include in full setup: `sudo bash initial_setup.sh --full` (if ENABLE_FAIL2BAN=true)

This will automatically:
- Install fail2ban if not present (supports apt-get, yum, dnf)
- Configure filters for n8n webhooks and healthman API authentication
- Set up jails with appropriate ban times and retry limits:
  - **n8n-webhook**: 5 failed attempts → 1 hour ban
  - **healthman-auth**: 3 failed attempts → 2 hour ban
- Create `/var/log/caddy/` directory for log monitoring
- Enable and start fail2ban service

**Note**: Requires Caddy logs to be written to `/var/log/caddy/` for fail2ban to monitor. Uncomment the log configuration in `Caddyfile.template` to enable file logging.

#### 5. **nginx with ModSecurity** (Alternative Reverse Proxy)

If you prefer nginx over Caddy, ModSecurity integration is well-documented:

- **Setup**: Replace Caddy with nginx, install ModSecurity
- **Documentation**: [nginx ModSecurity Guide](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual)

### Implementation Recommendation

**For most users: Start with Cloudflare**

1. **Immediate Protection**: Set up Cloudflare for DNS (free tier includes basic WAF)
2. **Additional Security**: Add fail2ban on your server for SSH and application-level protection
3. **Advanced**: Consider Caddy Security Plugin or ModSecurity for deeper integration

### Hardening Checklist

- [ ] Enable Cloudflare WAF (if using Cloudflare DNS)
- [ ] Install and configure fail2ban (set `ENABLE_FAIL2BAN=true` and run `sudo bash initial_setup.sh --fail2ban`)
- [ ] Set up rate limiting in Caddy (caddy-security module already included, uncomment in Caddyfile.template)
- [ ] Enable Caddy file logging for fail2ban (uncomment log block in Caddyfile.template)
- [ ] Configure CORS properly (restrict origins, don't use `*` in production)
- [ ] Enable basic authentication where available (n8n already configured)
- [ ] Regularly update all containers
- [ ] Monitor logs for suspicious activity
- [ ] Configure caddy-security features as needed (JWT, IP filtering, bot protection)

### Caddy Security Module

The Caddy Dockerfile already includes the [caddy-security](https://github.com/greenpau/caddy-security) module, which provides:

- **Rate Limiting**: Protect against DDoS and brute force attacks
- **JWT Authentication**: Secure API endpoints
- **IP Filtering**: Block or allow specific IPs
- **Bot Protection**: Filter malicious bots
- **Authentication Portal**: User authentication gateway

**Current Status**: ✅ **Already Integrated**

The Caddy image is built with caddy-security module included. To enable features:

1. **Uncomment rate limiting** in `docker_configs/caddy/Caddyfile.template` (see example comments)
2. **Add security blocks** to your Caddyfile for specific protection needs
3. **Rebuild Caddy** if you've already built it: `docker compose build caddy`

**Example Caddyfile with Security:**
```caddy
{
email admin@example.com
log {
    output file /var/log/caddy/access.log
}
}

example.com {
    rate_limit {
        zone dynamic {
            key {remote_host}
            events 50
            window 1m
        }
    }
    reverse_proxy app:8080
}
```

**Note**: For basic protection, start with Cloudflare and fail2ban. Enable caddy-security features as needed.

## License

This project uses various open-source software packages. Please refer to individual project licenses.

## Contributing

Contributions are welcome! Please ensure:
- Directory structure is maintained
- Environment variables are documented
- Dockerfiles follow best practices
- README is updated with changes
