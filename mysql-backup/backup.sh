#!/bin/bash
set -euo pipefail

# Colori ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Caricamento application e variabili d'ambiente
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
set -a
. /etc/environment
set +a

LOG_FILE="/var/log/backup.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

log() {
  echo -e "${BLUE}🚀 [$(date +"%Y-%m-%d %H:%M:%S")] $1 ${RESET}" | tee -a "$LOG_FILE"
}
log_success() {
  echo -e "${GREEN}✅ [$(date +"%Y-%m-%d %H:%M:%S")] ✅ SUCCESSO: $1 ${RESET}" | tee -a "$LOG_FILE"
}
log_error() {
  echo -e "${RED}❌ [$(date +"%Y-%m-%d %H:%M:%S")] ERRORE: $1 ${RESET}" | tee -a "$LOG_FILE" >&2
}
separator() {
  echo -e "\n${YELLOW}============================================================${RESET}" | tee -a "$LOG_FILE"
  echo -e "${YELLOW}🕒  Nuova esecuzione del backup - $(date '+%Y-%m-%d %H:%M:%S')${RESET}" | tee -a "$LOG_FILE"
  echo -e "${YELLOW}============================================================${RESET}\n" | tee -a "$LOG_FILE"
}

# Controlla che le variabili esistano in modo automatico e stampa errore se non esiste
: "${MYSQL_HOST:?Variabile MYSQL_HOST mancante}"
: "${MYSQL_USER:?Variabile MYSQL_USER mancante}"
: "${MYSQL_DATABASE:?Variabile MYSQL_DATABASE mancante}"
: "${AWS_S3_URI:?Variabile AWS_S3_URI mancante}"

BACKUP_FILE="dump_$(date +%Y%m%d-%H%M%S).sql"

separator
log "\n Avvio backup MySQL → S3...\n"

log "Inizio mysqldump del database '$MYSQL_DATABASE' da host '$MYSQL_HOST'..."
if ! mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" "$MYSQL_DATABASE" > "$BACKUP_FILE" 2>dump_error.log; then
  log_error "mysqldump fallito! Dettagli:"
  cat dump_error.log | tee -a "$LOG_FILE" >&2
  rm -f dump_error.log
  exit 1
fi
log_success "Dump completato: $BACKUP_FILE"
rm -f dump_error.log

log "Caricamento su S3 (${AWS_S3_URI})"
if ! aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" $AWS_OTHER_OPTIONS 2>aws_error.log; then
  log_error "Errore durante upload su S3! Comando impartito: 'aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" $AWS_OTHER_OPTIONS'  Dettagli:"
  cat aws_error.log | tee -a "$LOG_FILE" >&2
  rm -f aws_error.log
  exit 1
fi
log_success "Upload completato su S3."
rm -f aws_error.log

rm -f "$BACKUP_FILE"
log_success "Backup completato con successo!"
