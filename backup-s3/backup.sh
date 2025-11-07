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

finalSeparator() {
  echo -e "\n${BLUE}============================================================${RESET}" | tee -a "$LOG_FILE"
  echo -e "${BLUE}📋  RIEPILOGO FINALE: - $(date '+%Y-%m-%d %H:%M:%S')${RESET}" | tee -a "$LOG_FILE"
  echo -e "${BLUE}============================================================${RESET}\n" | tee -a "$LOG_FILE"
}

report_result() {
  # 0 default
  # 1 successo
  # 2 errore
  local NAME=$1
  local RESULT=$2
  case $RESULT in
#    0) log_success "$NAME: completato con successo" ;;
    1) log_error   "$NAME: errore durante il dump" ;;
    2) log_success   "$NAME: completato con successo" ;;
    *) log_error   "$NAME: errore sconosciuto (codice $RESULT)" ;;
  esac
}

print_next_cron() {
  local CRON_FILE="/etc/cron.d/backup-cron"
  if [[ -f "$CRON_FILE" ]]; then
    local CRON_EXPR
    CRON_EXPR=$(grep -v '^#' "$CRON_FILE" | grep backup.sh | head -n 1 | awk '{print $1,$2,$3,$4,$5}')
    if [[ -n "$CRON_EXPR" ]]; then
      echo -e "\n${YELLOW}🕒 Prossima esecuzione pianificata (cron): ${CRON_EXPR}${RESET}" | tee -a "$LOG_FILE"
    fi
  fi
}

mysqlBackup() {
  # Controlla che le variabili esistano in modo automatico e stampa errore se non esiste
  : "${MYSQL_HOST:?Variabile MYSQL_HOST mancante}"
  : "${MYSQL_USER:?Variabile MYSQL_USER mancante}"
  : "${MYSQL_DATABASE:?Variabile MYSQL_DATABASE mancante}"
  : "${AWS_S3_MYSQL_BACKUP_URI:?Variabile AWS_S3_MYSQL_BACKUP_URI mancante}"


  AWS_S3_URI="$AWS_S3_MYSQL_BACKUP_URI"
  BACKUP_FILE="dump_$(date +%Y%m%d-%H%M%S).sql"

  # Controlla che la variabile non sia vuota, se lo è imposta valore di default
    : "${MYSQL_PORT:=3306}"

  separator
  log "\n Avvio backup MySQL → S3...\n"

  log "Inizio mysqldump del database '$MYSQL_DATABASE' da host '$MYSQL_HOST'..."
  if ! mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DATABASE" > "$BACKUP_FILE" 2>dump_error.log; then
    log_error "mysqldump fallito! Comando pg_dump impartito: 'mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DATABASE" > "$BACKUP_FILE"' Dettagli:"
    cat dump_error.log | tee -a "$LOG_FILE" >&2
    rm -f dump_error.log
    return 1
  fi
  log_success "Dump completato: $BACKUP_FILE"
  rm -f dump_error.log

  log "Caricamento su S3 (${AWS_S3_URI})"
  if ! aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" ${AWS_OTHER_OPTIONS:+$AWS_OTHER_OPTIONS} 2>aws_error.log; then
    log_error "Errore durante upload su S3! Comando impartito: 'aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" ${AWS_OTHER_OPTIONS:+$AWS_OTHER_OPTIONS}'  Dettagli:"
    cat aws_error.log | tee -a "$LOG_FILE" >&2
    rm -f aws_error.log
    return 1
  fi
  log_success "Upload completato su S3."
  rm -f aws_error.log

  rm -f "$BACKUP_FILE"
  log_success "Backup completato con successo!"

  return 2
}

postgresBackup() {
  # Controlla che le variabili esistano in modo automatico e stampa errore se non esiste
  : "${PGHOST:?Variabile PGHOST mancante}"
  : "${PGUSER:?Variabile PGUSER mancante}"
  : "${PGPASSWORD:?Variabile PGPASSWORD mancante}"
  : "${PGDATABASE:?Variabile PGDATABASE mancante}"
  : "${AWS_S3_PG_BACKUP_URI:?Variabile AWS_S3_PG_BACKUP_URI mancante}"


  AWS_S3_URI="$AWS_S3_PG_BACKUP_URI"
  BACKUP_FILE="dump_$(date +%Y%m%d-%H%M%S).dump"

  # Controlla che la variabile non sia vuota, se lo è imposta valore di default
  : "${PGPORT:=5432}"

  separator
  log "\n Avvio backup Postgres → S3...\n"

  log "Inizio pg_dump del database '$PGDATABASE' da host '$PGHOST'..."
  if ! pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" > "$BACKUP_FILE" 2>dump_error.log; then
    log_error "pg_dump fallito! Comando pg_dump impartito: 'pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" > "$BACKUP_FILE"'. Dettagli:"
    cat dump_error.log | tee -a "$LOG_FILE" >&2
    rm -f dump_error.log
    return 1
  fi
  log_success "Dump completato: $BACKUP_FILE"
  rm -f dump_error.log

  log "Caricamento su S3 (${AWS_S3_URI})"
  if ! aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" ${AWS_OTHER_OPTIONS:+$AWS_OTHER_OPTIONS} 2>aws_error.log; then
    log_error "Errore durante upload su S3! Comando impartito: 'aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" ${AWS_OTHER_OPTIONS:+$AWS_OTHER_OPTIONS}'  Dettagli:"
    cat aws_error.log | tee -a "$LOG_FILE" >&2
    rm -f aws_error.log
    return 1
  fi
  log_success "Upload completato su S3."
  rm -f aws_error.log

  rm -f "$BACKUP_FILE"
  log_success "Backup completato con successo!"

  return 2
}

mongoBackup() {
  # Controlla che le variabili esistano in modo automatico e stampa errore se non esiste
  : "${MONGO_HOST:?Variabile MONGO_HOST mancante}"
  : "${MONGO_DATABASE:?Variabile MONGO_DATABASE mancante}"
  : "${AWS_S3_MONGO_BACKUP_URI:?Variabile AWS_S3_MONGO_BACKUP_URI mancante}"


  AWS_S3_URI="$AWS_S3_MONGO_BACKUP_URI"
  BACKUP_FILE="mongo_$(date +%Y%m%d-%H%M%S).gz"

  separator

  # Controlla che la variabile non sia vuota, se lo è imposta valore di default
  : "${MONGO_PORT:=27017}"
  MONGO_USER="${MONGO_USER:-}" # Se non valorizzata mette stringa vuota
  MONGO_PASSWORD="${MONGO_PASSWORD:-}" # Se non valorizzata mette stringa vuota
  MONGO_URI_CONNECTION_OPTIONS="${MONGO_URI_CONNECTION_OPTIONS:-}" # Se non valorizzata mette stringa vuota

  MONGO_URI=""
  # Se username e password sono impostati → usa autenticazione
  if [[ -n "$MONGO_USER" && -n "$MONGO_PASSWORD" ]]; then
      MONGO_URI="mongodb://${MONGO_USER}:${MONGO_PASSWORD}@${MONGO_HOST}:${MONGO_PORT}/${MONGO_DATABASE}${MONGO_URI_CONNECTION_OPTIONS}"
  else
      MONGO_URI="mongodb://${MONGO_HOST}:${MONGO_PORT}/${MONGO_DATABASE}${MONGO_URI_CONNECTION_OPTIONS}"
  fi

  log "\n Avvio backup Mongo → S3...\n"

  log "Inizio mongodump del database '$MONGO_DATABASE' da host '$MONGO_URI'..."
  if ! mongodump --uri="$MONGO_URI" --archive="$BACKUP_FILE" --gzip 2> dump_error.log; then
    log_error "mongodump fallito! Comando mongodump impartito: 'mongodump --uri="$MONGO_URI" --archive="$BACKUP_FILE" --gzip'. Dettagli:"
    cat dump_error.log | tee -a "$LOG_FILE" >&2
    rm -f dump_error.log
    return 1
  fi
  log_success "Dump completato: $BACKUP_FILE"
  rm -f dump_error.log

  log "Caricamento su S3 (${AWS_S3_URI})"
  if ! aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" ${AWS_OTHER_OPTIONS:+$AWS_OTHER_OPTIONS} 2>aws_error.log; then
    log_error "Errore durante upload su S3! Comando impartito: 'aws s3 cp "$BACKUP_FILE" "${AWS_S3_URI}/${BACKUP_FILE}" ${AWS_OTHER_OPTIONS:+$AWS_OTHER_OPTIONS}'  Dettagli:"
    cat aws_error.log | tee -a "$LOG_FILE" >&2
    rm -f aws_error.log
    return 1
  fi
  log_success "Upload completato su S3."
  rm -f aws_error.log

  rm -f "$BACKUP_FILE"
  log_success "Backup completato con successo!"

  return 2
}

# Controlla che la variabile non sia vuota, se lo è imposta valore di default "false"
: "${ENABLE_MYSQL_BACKUP:='false'}"
: "${ENABLE_PG_BACKUP:='false'}"
: "${ENABLE_MONGO_BACKUP:='false'}"

set +e

MYSQL_RESULT=0
PG_RESULT=0
MONGO_RESULT=0

[[ "${ENABLE_MYSQL_BACKUP,,}" =~ ^(true|1|yes)$ ]] && mysqlBackup || MYSQL_RESULT=$?
[[ "${ENABLE_PG_BACKUP,,}" =~ ^(true|1|yes)$ ]] && postgresBackup || PG_RESULT=$?
[[ "${ENABLE_MONGO_BACKUP,,}" =~ ^(true|1|yes)$ ]] && mongoBackup || MONGO_RESULT=$?

set -e

finalSeparator

[[ "${ENABLE_MYSQL_BACKUP,,}" =~ ^(true|1|yes)$ ]] && report_result "MySQL" "$MYSQL_RESULT"
[[ "${ENABLE_PG_BACKUP,,}" =~ ^(true|1|yes)$ ]] && report_result "PostgreSQL" "$PG_RESULT"
[[ "${ENABLE_MONGO_BACKUP,,}" =~ ^(true|1|yes)$ ]] && report_result "MongoDB" "$MONGO_RESULT"

log "\n✅ Fine esecuzione\n"
print_next_cron