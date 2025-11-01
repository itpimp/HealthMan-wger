# HealthMan-wger

A self-hosted health tracking and planning environment, using mature, open-source, self-hosted tools.

## Overview

HealthMan-wger integrates multiple open-source health and fitness applications into a unified, self-hosted stack:

- **wger** - Workout and exercise tracking with custom fasting extension
- **Tandoor Recipes** - Recipe management and meal planning
- **n8n** - Workflow automation for health data synchronization
- **Grafana** - Health metrics visualization and dashboards
- **Caddy** - Reverse proxy with automatic HTTPS

## Project Structure

```
HealthMan-wger/
├── docker-compose.yml       # Main orchestration file (in root)
├── initial_setup.sh         # Consolidated setup script
├── docker_definitions/      # Docker build definitions
│   ├── wger/
│   │   └── Dockerfile       # Custom wger image with extensions
│   └── tandoor/
│       └── Dockerfile       # Custom Tandoor image
├── docker_configs/          # Configuration and customization files
│   ├── caddy/              # Caddy reverse proxy config
│   │   ├── Caddyfile       # Active Caddyfile (generated from template)
│   │   └── Caddyfile.template  # Template for customization
│   ├── wger_extensions/     # Custom wger extensions
│   │   └── fasting_extension/  # Fasting tracking extension
│   ├── grafana/            # Grafana provisioning configs
│   │   └── provisioning/
│   │       ├── dashboards/ # Dashboard definitions
│   │       └── datasources/ # Data source configurations
│   └── n8n_workflows/       # n8n automation workflows
├── docker_data/            # Persistent data storage (gitignored)
│   ├── postgres/           # PostgreSQL data
│   ├── redis/              # Redis data
│   ├── wger/               # wger application data
│   ├── tandoor/            # Tandoor media files
│   ├── n8n/                # n8n workflow data
│   ├── grafana/            # Grafana configuration
│   └── caddy/               # Caddy certificates and data
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
   
   Or for full setup (env + Caddyfile + migrations):
   ```bash
   bash initial_setup.sh --full
   ```

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

## License

This project uses various open-source software packages. Please refer to individual project licenses.

## Contributing

Contributions are welcome! Please ensure:
- Directory structure is maintained
- Environment variables are documented
- Dockerfiles follow best practices
- README is updated with changes
