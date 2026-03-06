# Migration Scripts

Scripts pour la migration de Tutor vers le setup Docker Compose natif.

## 📋 Scripts disponibles

### 1. `backup-verify.sh`
Vérifie l'intégrité des backups avant migration.

**Usage:**
```bash
./backup-verify.sh
```

**Variables d'environnement:**
- `MYSQL_BACKUP`: Chemin du backup MySQL (défaut: `mysql-backup.sql`)
- `MONGO_BACKUP_DIR`: Répertoire du backup MongoDB (défaut: `mongo-backup`)
- `MEDIA_BACKUP_DIR`: Répertoire du backup media (défaut: `media-backup`)
- `DATA_BACKUP_DIR`: Répertoire du backup data (défaut: `data-backup`)

### 2. `migrate-mysql.sh`
Migre la base de données MySQL de Tutor vers le setup natif.

**Usage:**
```bash
export MYSQL_ROOT_PASSWORD="your-password"
./migrate-mysql.sh
```

**Variables d'environnement:**
- `BACKUP_FILE`: Fichier de backup MySQL (défaut: `mysql-backup.sql`)
- `MYSQL_CONTAINER`: Nom du conteneur MySQL (défaut: `openedx-mysql`)
- `MYSQL_ROOT_PASSWORD`: Mot de passe root MySQL (requis)
- `DRY_RUN`: Mode dry-run (défaut: `false`)

**Dry-run:**
```bash
DRY_RUN=true ./migrate-mysql.sh
```

### 3. `migrate-mongodb.sh`
Migre la base de données MongoDB de Tutor vers le setup natif.

**Usage:**
```bash
./migrate-mongodb.sh
```

**Variables d'environnement:**
- `BACKUP_DIR`: Répertoire du backup MongoDB (défaut: `mongo-backup`)
- `MONGODB_CONTAINER`: Nom du conteneur MongoDB (défaut: `openedx-mongodb`)
- `MONGO_DATABASE`: Nom de la base de données (défaut: `openedx`)
- `DRY_RUN`: Mode dry-run (défaut: `false`)

### 4. `migrate-media.sh`
Migre les fichiers media et data de Tutor vers le setup natif.

**Usage:**
```bash
./migrate-media.sh
```

**Variables d'environnement:**
- `MEDIA_BACKUP_DIR`: Répertoire du backup media (défaut: `media-backup`)
- `DATA_BACKUP_DIR`: Répertoire du backup data (défaut: `data-backup`)
- `MEDIA_VOLUME`: Volume Docker pour media (défaut: `openedx_media`)
- `DATA_VOLUME`: Volume Docker pour data (défaut: `openedx_data`)
- `DRY_RUN`: Mode dry-run (défaut: `false`)

### 5. `migrate-with-rollback.sh`
Orchestre la migration complète avec rollback automatique en cas d'échec.

**Usage:**
```bash
export MYSQL_ROOT_PASSWORD="your-password"
./migrate-with-rollback.sh
```

**Variables d'environnement:**
- `BACKUP_DIR`: Répertoire des backups (défaut: `backups`)
- `ROLLBACK_BACKUP`: Nom du point de rollback (défaut: `rollback-YYYYMMDD-HHMMSS`)
- `DRY_RUN`: Mode dry-run (défaut: `false`)

### 6. `rollback.sh`
Effectue un rollback vers Tutor en cas de problème.

**Usage:**
```bash
./rollback.sh
```

**Actions:**
- Arrête le setup natif
- Fournit les commandes pour redémarrer Tutor
- Préserve les données du setup natif

### 7. `health-check.sh`
Vérifie la santé de tous les services.

**Usage:**
```bash
./health-check.sh
```

**Variables d'environnement:**
- `LMS_URL`: URL du LMS (défaut: `http://localhost`)
- `CMS_URL`: URL du CMS (défaut: `http://localhost:8001`)
- `TIMEOUT`: Timeout des requêtes HTTP (défaut: `10`)

## 🚀 Workflow de migration

### Étape 1: Vérification des backups
```bash
./backup-verify.sh
```

### Étape 2: Migration complète (recommandé)
```bash
export MYSQL_ROOT_PASSWORD="your-password"
./migrate-with-rollback.sh
```

### Étape 3: Vérification de la santé
```bash
./health-check.sh
```

### En cas de problème: Rollback
```bash
./rollback.sh
```

## 🧪 Mode Dry-Run

Tous les scripts de migration supportent le mode dry-run pour tester sans modifier les données:

```bash
DRY_RUN=true ./migrate-mysql.sh
DRY_RUN=true ./migrate-mongodb.sh
DRY_RUN=true ./migrate-media.sh
DRY_RUN=true ./migrate-with-rollback.sh
```

## 📊 Logs et rapports

Les scripts génèrent automatiquement des rapports:
- `backup-verification-YYYYMMDD-HHMMSS.txt`: Rapport de vérification des backups
- `health-check-YYYYMMDD-HHMMSS.txt`: Rapport de santé des services

## ⚠️ Prérequis

- Docker et Docker Compose installés
- Backups Tutor disponibles:
  - `mysql-backup.sql`
  - `mongo-backup/`
  - `media-backup/`
  - `data-backup/`
- Variables d'environnement configurées (notamment `MYSQL_ROOT_PASSWORD`)
- Volumes Docker créés pour le setup natif

## 🔒 Sécurité

- Ne jamais commiter les backups dans Git
- Utiliser des variables d'environnement pour les mots de passe
- Vérifier les permissions des fichiers de backup (600 recommandé)
- Conserver les backups dans un emplacement sécurisé

## 📝 Troubleshooting

### Erreur: "MySQL container not running"
```bash
docker-compose up -d mysql
docker-compose ps
```

### Erreur: "Backup file not found"
Vérifier que les backups sont dans le bon répertoire:
```bash
ls -lah mysql-backup.sql mongo-backup/ media-backup/ data-backup/
```

### Erreur: "Permission denied"
Rendre les scripts exécutables:
```bash
chmod +x scripts/*.sh
```

### Vérifier les logs en cas d'erreur
```bash
docker-compose logs --tail=100 mysql
docker-compose logs --tail=100 mongodb
docker-compose logs --tail=100 lms
```
