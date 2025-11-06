# backup-s3 – Backup automatico MySQL, PostgreSQL e MongoDB su S3

Il container **`backup-s3`** gestisce il backup automatico dei database **MySQL**, **PostgreSQL** e **MongoDB** su **Amazon S3**.
Si basa sull’immagine `overzoomit/backup/s3` (una versione personalizzata costruita da `./backup-s3/Dockerfile`) e consente di eseguire **dump periodici** dei database abilitati, inviandoli in modo sicuro su un bucket S3.

---

## 🧩 Struttura generale

Il container è definito come servizio nel `docker-compose.yml`:

```yaml
backup-s3:
  image: overzoomit/backup/s3
  container_name: backup-s3
  hostname: backup-s3
  restart: always
  build:
    context: ./backup-s3
    dockerfile: Dockerfile
    args:
      PG_VERSION: 16
      MONGO_VERSION: 7.0
  environment:
    # MYSQL
    ENABLE_MYSQL_BACKUP: "yes"
    MYSQL_HOST: mysql-db
    MYSQL_PORT: 3306
    MYSQL_USER: root
    MYSQL_PWD: password
    MYSQL_DATABASE: test-backup
    AWS_S3_MYSQL_BACKUP_URI: s3-uri
    # POSTGRES
    ENABLE_PG_BACKUP: "yes"
    PGHOST: postgres-db
    PGPORT: 5432
    PGUSER: root
    PGPASSWORD: password
    PGDATABASE: postgres
    AWS_S3_PG_BACKUP_URI: s3-uri
    # MONGO
    ENABLE_MONGO_BACKUP: "yes"
    MONGO_HOST: mongo-db
    MONGO_PORT: 27017
    MONGO_USER:
    MONGO_PASSWORD:
    MONGO_DATABASE: test-backup
    AWS_S3_MONGO_BACKUP_URI: s3-uri
    # AWS
    AWS_ACCESS_KEY_ID: s3-key-id
    AWS_SECRET_ACCESS_KEY: s3-key-secret
    AWS_DEFAULT_REGION: s3-region
    AWS_OTHER_OPTIONS: "--storage-class DEEP_ARCHIVE --progress-frequency 60"
  volumes:
    - ./backup-s3/logs:/var/log
```

---

## ⚙️ Variabili d’ambiente

### 🔹 Generali AWS

| Variabile                 | Descrizione                                          | Esempio                                                |
| ------------------------- | ---------------------------------------------------- | ------------------------------------------------------ |
| **AWS_ACCESS_KEY_ID**     | Access key AWS con permessi di scrittura sul bucket. | `s3-key-id`                                            |
| **AWS_SECRET_ACCESS_KEY** | Secret key AWS associata all’access key.             | `s3-key-secret`                                        |
| **AWS_DEFAULT_REGION**    | Regione AWS in cui risiede il bucket.                | `s3-region`                                            |
| **AWS_OTHER_OPTIONS**     | Opzioni aggiuntive per il client S3.                 | `--storage-class DEEP_ARCHIVE --progress-frequency 60` |

> ⚠️ Non includere virgolette nel valore della variabile.

---

### 🔹 Backup MySQL

| Variabile                   | Descrizione                                        | Esempio                         |
| --------------------------- | -------------------------------------------------- | ------------------------------- |
| **ENABLE_MYSQL_BACKUP**     | Abilita o disabilita il backup MySQL (`yes`/`no`). | `yes`                           |
| **MYSQL_HOST**              | Host o container del database MySQL.               | `mysql-db`                      |
| **MYSQL_PORT**              | Porta del servizio MySQL (default `3306`).         | `3306`                          |
| **MYSQL_USER**              | Utente MySQL.                                      | `root`                          |
| **MYSQL_PWD**               | Password MySQL.                                    | `password`                      |
| **MYSQL_DATABASE**          | Nome del database da esportare.                    | `test-backup`                   |
| **AWS_S3_MYSQL_BACKUP_URI** | Percorso S3 dove salvare il dump MySQL.            | `s3://my-bucket/mysql-backups/` |

---

### 🔹 Backup PostgreSQL

| Variabile                | Descrizione                                             | Esempio                            |
| ------------------------ | ------------------------------------------------------- | ---------------------------------- |
| **ENABLE_PG_BACKUP**     | Abilita o disabilita il backup PostgreSQL (`yes`/`no`). | `yes`                              |
| **PGHOST**               | Host o container PostgreSQL.                            | `postgres-db`                      |
| **PGPORT**               | Porta del servizio PostgreSQL (default `5432`).         | `5432`                             |
| **PGUSER**               | Utente PostgreSQL.                                      | `root`                             |
| **PGPASSWORD**           | Password PostgreSQL.                                    | `password`                         |
| **PGDATABASE**           | Nome del database da esportare.                         | `postgres`                         |
| **AWS_S3_PG_BACKUP_URI** | Percorso S3 dove salvare il dump PostgreSQL.            | `s3://my-bucket/postgres-backups/` |

---

### 🔹 Backup MongoDB

| Variabile                   | Descrizione                                          | Esempio                         |
| --------------------------- | ---------------------------------------------------- | ------------------------------- |
| **ENABLE_MONGO_BACKUP**     | Abilita o disabilita il backup MongoDB (`yes`/`no`). | `yes`                           |
| **MONGO_HOST**              | Host o container MongoDB.                            | `mongo-db`                      |
| **MONGO_PORT**              | Porta del servizio MongoDB (default `27017`).        | `27017`                         |
| **MONGO_USER**              | Utente MongoDB (opzionale).                          | `root`                          |
| **MONGO_PASSWORD**          | Password MongoDB (opzionale).                        | `password`                      |
| **MONGO_DATABASE**          | Nome del database da esportare.                      | `test-backup`                   |
| **AWS_S3_MONGO_BACKUP_URI** | Percorso S3 dove salvare il dump MongoDB.            | `s3://my-bucket/mongo-backups/` |

---

## ⚙️ Argomenti di build (ARG)

Nel blocco `build.args` del `docker-compose.yml` è possibile specificare versioni **personalizzate** dei client di backup per PostgreSQL e MongoDB:

```yaml
args:
  PG_VERSION: 16
  MONGO_VERSION: 7.0
```

### 🔹 Funzionamento intelligente

* Se **`PG_VERSION`** o **`MONGO_VERSION`** vengono specificati, il Dockerfile installerà **solo** i client corrispondenti (`pg_dump`, `mongodump`).
* Se **non vengono valorizzati**, l’installazione di quei client viene **saltata automaticamente**, permettendo di creare un’immagine più leggera e veloce.
* È quindi possibile costruire immagini:

    * **minimali** (solo MySQL),
    * **ibride** (ad esempio MySQL + MongoDB),
    * oppure **complete** (tutti e tre i DB).

---

## 💾 Volumi

| Percorso nel container | Descrizione                                      |
| ---------------------- | ------------------------------------------------ |
| `/var/log`             | Directory dove vengono salvati i log dei backup. |

Esempio:

```yaml
volumes:
  - ./backup-s3/logs:/var/log
```

---

## 🕒 Pianificazione automatica (cron)

Il container usa **cron** per pianificare i backup.
La configurazione si trova in:

```
backup-s3/crontab.txt
```

### Contenuto predefinito

```bash
SHELL=/bin/bash
BASH_ENV=/root/.bashrc
* 1 * * * root /app/backup.sh
```

Esegue tutti i backup abilitati ogni giorno alle **01:00**.

| Obiettivo             | Riga cron                          | Descrizione                      |
| --------------------- | ---------------------------------- | -------------------------------- |
| Ogni giorno alle 3:00 | `0 3 * * * root /app/backup.sh`    | Backup giornaliero alle 03:00    |
| Ogni 6 ore            | `0 */6 * * * root /app/backup.sh`  | Backup ogni 6 ore                |
| Ogni 15 minuti        | `*/15 * * * * root /app/backup.sh` | Backup frequente (solo per test) |

> Dopo le modifiche, ricostruire il container:
>
> ```bash
> docker compose up --build -d backup-s3
> ```

---

## ▶️ Avvio e utilizzo

Per buildare e avviare il servizio:

```bash
docker compose up --build -d backup-s3
```

Il container eseguirà automaticamente i backup secondo la pianificazione definita in `crontab.txt`.

---

## 🔧 Esempi di configurazione

### 🧠 Esempio 1 – Backup solo di PostgreSQL

Esegue il backup esclusivamente del database PostgreSQL ogni giorno alle 02:00, installando **solo il client `pg_dump` versione 16**:

```yaml
backup-s3:
  build:
    context: ./backup-s3
    dockerfile: Dockerfile
    args:
      PG_VERSION: 16
  environment:
    ENABLE_PG_BACKUP: "yes"
    PGHOST: postgres-db
    PGPORT: 5432
    PGUSER: root
    PGPASSWORD: password
    PGDATABASE: postgres
    AWS_S3_PG_BACKUP_URI: s3-uri

    AWS_ACCESS_KEY_ID: s3-key-id
    AWS_SECRET_ACCESS_KEY: s3-key-secret
    AWS_DEFAULT_REGION: s3-region
    AWS_OTHER_OPTIONS: 'option same: "--storage-class DEEP_ARCHIVE and --progress-frequency 60" (without "")'
```

> ⚠️ Informarsi sulla versione di postgres che ha l'istanza sul quale si vuole fare il backup. Modificare di conseguenza l'arg: "PG_VERSION". <br>
> La variabile "PGPORT" ha come valore di default: 5432. <br>

**Crontab personalizzato (`backup-s3/crontab.txt`):**

```bash
0 2 * * * root /app/backup.sh
```

---

### 🧠 Esempio 2 – Backup solo di MySQL

Esegue il backup esclusivamente del database MySQL ogni giorno alle 02:00, installando **solo il client `mysqldump` versione 8**:

```yaml
backup-s3:
  build:
    context: ./backup-s3
    dockerfile: Dockerfile
    args:
      PG_VERSION: 16
  environment:
    ENABLE_MYSQL_BACKUP: "yes"
    MYSQL_HOST: mysql-db
    MYSQL_PORT: 3306
    MYSQL_USER: root
    MYSQL_PWD: password
    MYSQL_DATABASE: test-backup
    AWS_S3_MYSQL_BACKUP_URI: s3://overzoom-backups/salvatore/sms/tests

    AWS_ACCESS_KEY_ID: s3-key-id
    AWS_SECRET_ACCESS_KEY: s3-key-secret
    AWS_DEFAULT_REGION: s3-region
    AWS_OTHER_OPTIONS: 'option same: "--storage-class DEEP_ARCHIVE and --progress-frequency 60" (without "")'
```

> ⚠️ La variabile "MYSQL_PORT" ha come valore di default: 3306


**Crontab personalizzato (`backup-s3/crontab.txt`):**

```bash
0 2 * * * root /app/backup.sh
```

---

### 💾 Esempio 3 – Backup combinato di MySQL e MongoDB ogni 6 ore

Installa il client **MongoDB versione 7.0** e salta PostgreSQL.
Esegue i backup ogni 6 ore.

```yaml
backup-s3:
  build:
    context: ./backup-s3
    dockerfile: Dockerfile
    args:
      MONGO_VERSION: 7.0
  environment:
    ENABLE_MYSQL_BACKUP: "yes"
    MYSQL_HOST: mysql-db
    MYSQL_PORT: 3306
    MYSQL_USER: root
    MYSQL_PWD: password
    MYSQL_DATABASE: test-backup
    AWS_S3_MYSQL_BACKUP_URI: s3://overzoom-backups/salvatore/sms/tests

    ENABLE_MONGO_BACKUP: "yes"
    MONGO_HOST: mongo-db
    MONGO_PORT: 27017
    MONGO_DATABASE: test-backup
    AWS_S3_MONGO_BACKUP_URI: s3://overzoom-backups/salvatore/sms/tests

    AWS_ACCESS_KEY_ID: s3-key-id
    AWS_SECRET_ACCESS_KEY: s3-key-secret
    AWS_DEFAULT_REGION: s3-region
    AWS_OTHER_OPTIONS: 'option same: "--storage-class DEEP_ARCHIVE and --progress-frequency 60" (without "")'
```

**Crontab (`backup-s3/crontab.txt`):**

```bash
0 */6 * * * root /app/backup.sh
```

---

### 🧩 Esempio 4 – Backup di tutti i database con versioni personalizzate

Installa **entrambi i client** (`pg_dump` e `mongodump`) e genera tre dump distinti caricati su S3.

```yaml
backup-s3:
  build:
    context: ./backup-s3
    dockerfile: Dockerfile
    args:
      PG_VERSION: 16
      MONGO_VERSION: 7.0
  environment:
    # MYSQL
    ENABLE_MYSQL_BACKUP: "yes"
    MYSQL_HOST: mysql-db
    MYSQL_PORT: 3306
    MYSQL_USER: root
    MYSQL_PWD: password
    MYSQL_DATABASE: test-backup
    AWS_S3_MYSQL_BACKUP_URI: s3://overzoom-backups/salvatore/sms/tests
    # POSTGRES
    ENABLE_PG_BACKUP: "yes"
    PGHOST: postgres-db
    PGPORT: 5432
    PGUSER: root
    PGPASSWORD: password
    PGDATABASE: postgres
    AWS_S3_PG_BACKUP_URI: s3://overzoom-backups/salvatore/sms/tests
    # MONGO
    ENABLE_MONGO_BACKUP: "yes"
    MONGO_HOST: mongo-db
    MONGO_PORT: 27017
    MONGO_USER:
    MONGO_PASSWORD:
    MONGO_DATABASE: test-backup
    AWS_S3_MONGO_BACKUP_URI: s3://overzoom-backups/salvatore/sms/tests
    # Aws
    AWS_ACCESS_KEY_ID: s3-key-id
    AWS_SECRET_ACCESS_KEY: s3-key-secret
    AWS_DEFAULT_REGION: s3-region
    AWS_OTHER_OPTIONS: 'option same: "--storage-class DEEP_ARCHIVE and --progress-frequency 60" (without "")'
```

---

### 🧱 Esempio 5 – Backup solo di MongoDB

Esegue il backup esclusivamente del database MongoDB, attraverso **il client `mongodump` versione: 7.0**:

```yaml
backup-s3:
  build:
    context: ./backup-s3
    dockerfile: Dockerfile
    args:
      MONGO_VERSION: 7.0
  environment:
    ENABLE_MONGO_BACKUP: "yes"
    MONGO_HOST: mongo-db
    MONGO_PORT: 27017
    MONGO_USER:
    MONGO_PASSWORD:
    MONGO_DATABASE: test-backup
    AWS_S3_MONGO_BACKUP_URI: s3://overzoom-backups/salvatore/sms/tests
    # Aws
    AWS_ACCESS_KEY_ID: s3-key-id
    AWS_SECRET_ACCESS_KEY: s3-key-secret
    AWS_DEFAULT_REGION: s3-region
    AWS_OTHER_OPTIONS: 'option same: "--storage-class DEEP_ARCHIVE and --progress-frequency 60" (without "")'
```

> ⚠️ La versione 7.0 è versatile e in molti casi basta e avanza per fare backup di mongo anche con versioni "vecchie" come 4+. <br>
> La variabile "MONGO_PORT" ha come valore di default: 27017. <br>
> Le variabili "MONGO_USER" e "MONGO_PASSWORD, possono essere lasciate vuoti se l'istanza di mongo è stata configurata senza autenticazione.
---

## 🧾 Log e troubleshooting

I log vengono salvati in:

```
./backup-s3/logs/backup.log
```

Per visualizzarli in tempo reale:

```bash
docker logs -f backup-s3
```

Se un backup fallisce, verifica:

* errori nei log;
* credenziali AWS e permessi sul bucket;
* che il database target sia raggiungibile;
* che le variabili `ENABLE_*_BACKUP` siano impostate su `yes`;
* che la pianificazione cron sia corretta.

---

## 📦 Note finali

* `backup-s3` è un container universale per backup MySQL, PostgreSQL e MongoDB.
* Ogni database può essere abilitato o disabilitato indipendentemente.
* I client PostgreSQL e MongoDB vengono installati solo se specificati come `ARG`.
* Può essere adattato facilmente per altri servizi compatibili con l’API S3 (MinIO, Wasabi, Backblaze B2, ecc.).
* Tutti i backup vengono gestiti dallo script comune `/app/backup.sh`.
* Se un argomento non è necessario, basta rimuoverlo: la build salterà automaticamente la sua installazione.
