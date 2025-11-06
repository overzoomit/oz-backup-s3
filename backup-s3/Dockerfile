FROM debian:bookworm-slim

ARG PG_VERSION
ARG MONGO_VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget gpg ca-certificates lsb-release && \
    mkdir -p /usr/share/keyrings && \
    \
    # Installa PostgreSQL client solo se PG_VERSION è impostato
    if [ -n "${PG_VERSION}" ]; then \
        echo "Installing PostgreSQL client version ${PG_VERSION}..." && \
        wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
            gpg --dearmor -o /usr/share/keyrings/postgres.gpg && \
        echo "deb [signed-by=/usr/share/keyrings/postgres.gpg] \
            http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
            > /etc/apt/sources.list.d/postgres.list && \
        apt-get update && \
        apt-get install -y --no-install-recommends "postgresql-client-${PG_VERSION}"; \
    else \
        echo "Skipping PostgreSQL client installation (PG_VERSION not set)"; \
    fi && \
    \
    # Installa default-mysql-client
    apt-get install -y --no-install-recommends \
        default-mysql-client \
        awscli bash ca-certificates && \
    rm -rf /var/lib/apt/lists/*


# install mongotools
RUN if [ -n "${MONGO_VERSION}" ]; then \
    apt-get update && \
    apt-get install -y wget gnupg ca-certificates && \
    wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/mongodb.gpg] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/${MONGO_VERSION} main" > /etc/apt/sources.list.d/mongodb-org.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mongodb-database-tools && \
    rm -rf /var/lib/apt/lists/* \
    else \
        echo "Skipping MongoDB installation because MONGO_VERSION is not set"; \
    fi

# Install aws-cli
RUN apt-get update && \
    apt-get install -y --no-install-recommends awscli cron && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

COPY crontab.txt /etc/cron.d/backup-cron
RUN chmod 0644 /etc/cron.d/backup-cron

ENTRYPOINT ["/app/entrypoint.sh"]