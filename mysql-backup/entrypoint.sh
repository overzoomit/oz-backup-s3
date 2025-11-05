#!/bin/bash
set -e

mkdir -p /root/.aws

cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF

cat > /root/.aws/config <<EOF
[default]
region = ${AWS_DEFAULT_REGION:-eu-central-1}
output = json
EOF

echo "configurazione credenziali aws completata! con attivi:"

# --- Cron setup ---
mkdir -p /var/log
touch /var/log/backup.log

echo "cron attivi:"
cat /etc/cron.d/backup-cron

chmod 0644 /etc/cron.d/backup-cron
sed -i -e '$a\' /etc/cron.d/backup-cron

crontab /etc/cron.d/backup-cron
crond

# Salva tutte le env Docker in /etc/environment per cron
printenv | grep -E '^(AWS_|MYSQL_)' | while IFS='=' read -r name value; do
  printf '%s="%s"\n' "$name" "$value"
done > /etc/environment

echo "Tail del log di cron..."
tail -F /var/log/backup.log
