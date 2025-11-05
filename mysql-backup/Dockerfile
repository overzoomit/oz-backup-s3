FROM mysql:8.0

RUN microdnf install -y unzip curl less tzdata bash cronie \
 && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
 && unzip awscliv2.zip \
 && ./aws/install \
 && rm -rf awscliv2.zip aws/ \
 && microdnf clean all

WORKDIR /app

COPY backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

COPY crontab.txt /etc/cron.d/backup-cron
RUN chmod 0644 /etc/cron.d/backup-cron

ENTRYPOINT ["/app/entrypoint.sh"]
