# PostgreSQL with optimizations
FROM postgres:17

# Tags
LABEL maintainer="JedAI Dev Team <richard.debreyn@gmail.com>"
LABEL description="Custom PostgreSQL 17 build for JedAI-HealthMan with tuned config and extensions"

## Copy configs and initialization SQL
# COPY configs/postgresql.conf /etc/postgresql/postgresql.conf

## Install common Postgres extensions and utils
COPY ./init/* /docker-entrypoint-initdb.d/

RUN chown -R postgres:postgres /var/lib/postgresql/data

## Prepare apt proxy
RUN cat <<EOF >/etc/apt/apt.conf.d/01proxy
Acquire::http { Proxy "http://${APT_PROXY_IP}:${APT_PROXY_PORT}"; };
Acquire::https { Proxy "http://${APT_PROXY_IP}:${APT_PROXY_PORT}"; };
EOF

RUN DEBIAN_FRONTEND="noninteractive" apt update --fix-missing;
RUN DEBIAN_FRONTEND="noninteractive" apt install -y --no-install-recommends \
      postgresql-contrib postgresql-plpython3-17 postgis curl \
      iotop nano;
RUN rm -rf /var/lib/apt/lists/*;

# Default runtime settings
EXPOSE 5432
HEALTHCHECK CMD pg_isready -U healthman || exit 1

# Use default PostgreSQL setup with optimizations
USER postgres

