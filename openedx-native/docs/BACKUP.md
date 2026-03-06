# Guide de Backup et Restore

Ce guide explique comment sauvegarder et restaurer le setup Open edX natif.

## 📋 Vue d'ensemble

Le setup natif utilise des volumes Docker pour la persistance des données. Les backups doivent couvrir:

1. **MySQL** - Base de données relationnelle (users, enrollments, grades, certificates)
2. **MongoDB** - Modulestore (course content, structure)
3. **Media files** - Fichiers uploadés (videos, PDFs, images, certificates)
4. **Application data** - Exports, logs, temporary files
5. **Configuration** - Fichiers de configuration (déjà dans Git)

## 🔄 Stratégie de backup

### Backup automatique (recommandé)

Configurer des backups automatiques quotidiens via cron ou Coolify.

### Backup manuel

Pour les migrations ou avant des changements critiques.

## 💾 Backup complet

### Script de backup automatisé

Créer un script `backup-all.sh`:

```bash
#!/bin/bash
# Backup complet du setup Open edX natif

set -e

BACKUP_DIR="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Starting backup to $BACKUP_DIR..."

# 1. Backup MySQL
echo "Backing up MySQL..."
docker-compose exec -T mysql mysqldump \
  -u root -p"$MYSQL_ROOT_PASSWORD" \
  --all-databases \
  --single-transaction \
  --quick \
  --lock-tables=false \
  > "$BACKUP_DIR/mysql-backup.sql"

# 2. Backup MongoDB
echo "Backing up MongoDB..."
docker-compose exec mongodb mongodump \
  --out=/tmp/mongo-backup \
  --gzip

docker cp openedx-mongodb:/tmp/mongo-backup "$BACKUP_DIR/mongo-backup"
docker-compose exec mongodb rm -rf /tmp/mongo-backup

# 3. Backup media files
echo "Backing up media files..."
docker run --rm \
  -v openedx_media:/source:ro \
  -v "$(pwd)/$BACKUP_DIR:/target" \
  alpine \
  tar czf /target/media-backup.tar.gz -C /source .

# 4. Backup application data
echo "Backing up application data..."
docker run --rm \
  -v openedx_data:/source:ro \
  -v "$(pwd)/$BACKUP_DIR:/target" \
  alpine \
  tar czf /target/data-backup.tar.gz -C /source .

# 5. Backup configuration (optionnel, déjà dans Git)
echo "Backing up configuration..."
tar czf "$BACKUP_DIR/config-backup.tar.gz" config/

# 6. Create backup manifest
cat > "$BACKUP_DIR/manifest.txt" << EOF
Backup Date: $(date)
MySQL Size: $(du -h "$BACKUP_DIR/mysql-backup.sql" | cut -f1)
MongoDB Size: $(du -h "$BACKUP_DIR/mongo-backup" | cut -f1)
Media Size: $(du -h "$BACKUP_DIR/media-backup.tar.gz" | cut -f1)
Data Size: $(du -h "$BACKUP_DIR/data-backup.tar.gz" | cut -f1)
Config Size: $(du -h "$BACKUP_DIR/config-backup.tar.gz" | cut -f1)
Total Size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

echo "Backup completed: $BACKUP_DIR"
cat "$BACKUP_DIR/manifest.txt"
```

### Exécution du backup

```bash
# Rendre le script exécutable
chmod +x backup-all.sh

# Exécuter le backup
export MYSQL_ROOT_PASSWORD="your-password"
./backup-all.sh
```

## 📥 Backup individuel

### MySQL uniquement

```bash
# Backup
docker-compose exec -T mysql mysqldump \
  -u root -p"$MYSQL_ROOT_PASSWORD" \
  --all-databases \
  > mysql-backup-$(date +%Y%m%d).sql

# Vérification
grep -q "CREATE TABLE" mysql-backup-*.sql && echo "OK" || echo "FAILED"
```

### MongoDB uniquement

```bash
# Backup
docker-compose exec mongodb mongodump \
  --out=/tmp/mongo-backup \
  --gzip

docker cp openedx-mongodb:/tmp/mongo-backup ./mongo-backup-$(date +%Y%m%d)

# Cleanup
docker-compose exec mongodb rm -rf /tmp/mongo-backup

# Vérification
ls -lah mongo-backup-*/
```

### Media files uniquement

```bash
# Backup
docker run --rm \
  -v openedx_media:/source:ro \
  -v "$(pwd):/target" \
  alpine \
  tar czf /target/media-backup-$(date +%Y%m%d).tar.gz -C /source .

# Vérification
tar tzf media-backup-*.tar.gz | head -20
```

## 🔄 Restore complet

### Prérequis

- Backup files disponibles
- Services Docker Compose démarrés
- Variables d'environnement configurées

### Script de restore automatisé

```bash
#!/bin/bash
# Restore complet du setup Open edX natif

set -e

BACKUP_DIR="${1:-backups/latest}"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Error: Backup directory not found: $BACKUP_DIR"
  exit 1
fi

echo "Starting restore from $BACKUP_DIR..."

# 1. Restore MySQL
echo "Restoring MySQL..."
docker-compose exec -T mysql mysql \
  -u root -p"$MYSQL_ROOT_PASSWORD" \
  < "$BACKUP_DIR/mysql-backup.sql"

# 2. Restore MongoDB
echo "Restoring MongoDB..."
docker cp "$BACKUP_DIR/mongo-backup" openedx-mongodb:/tmp/
docker-compose exec mongodb mongorestore \
  --drop \
  --gzip \
  /tmp/mongo-backup
docker-compose exec mongodb rm -rf /tmp/mongo-backup

# 3. Restore media files
echo "Restoring media files..."
docker run --rm \
  -v openedx_media:/target \
  -v "$(pwd)/$BACKUP_DIR:/source:ro" \
  alpine \
  sh -c "rm -rf /target/* && tar xzf /source/media-backup.tar.gz -C /target"

# 4. Restore application data
echo "Restoring application data..."
docker run --rm \
  -v openedx_data:/target \
  -v "$(pwd)/$BACKUP_DIR:/source:ro" \
  alpine \
  sh -c "rm -rf /target/* && tar xzf /source/data-backup.tar.gz -C /target"

# 5. Restart services
echo "Restarting services..."
docker-compose restart lms cms lms-worker cms-worker

echo "Restore completed from $BACKUP_DIR"
```

### Exécution du restore

```bash
# Rendre le script exécutable
chmod +x restore-all.sh

# Exécuter le restore
export MYSQL_ROOT_PASSWORD="your-password"
./restore-all.sh backups/20240315-120000
```

## 📥 Restore individuel

### MySQL uniquement

```bash
# Restore
docker-compose exec -T mysql mysql \
  -u root -p"$MYSQL_ROOT_PASSWORD" \
  < mysql-backup-20240315.sql

# Vérification
docker-compose exec mysql mysql \
  -u root -p"$MYSQL_ROOT_PASSWORD" \
  -e "SELECT COUNT(*) FROM openedx.auth_user;"
```

### MongoDB uniquement

```bash
# Restore
docker cp mongo-backup-20240315 openedx-mongodb:/tmp/
docker-compose exec mongodb mongorestore \
  --drop \
  --gzip \
  /tmp/mongo-backup-20240315

# Cleanup
docker-compose exec mongodb rm -rf /tmp/mongo-backup-20240315

# Vérification
docker-compose exec mongodb mongosh openedx \
  --eval "db.modulestore.active_versions.countDocuments()"
```

### Media files uniquement

```bash
# Restore
docker run --rm \
  -v openedx_media:/target \
  -v "$(pwd):/source:ro" \
  alpine \
  tar xzf /source/media-backup-20240315.tar.gz -C /target

# Vérification
docker run --rm -v openedx_media:/data alpine ls -lah /data
```

## 🔐 Sécurité des backups

### Chiffrement

```bash
# Backup chiffré
tar czf - backups/20240315-120000 | \
  gpg --symmetric --cipher-algo AES256 \
  > backup-20240315-encrypted.tar.gz.gpg

# Restore chiffré
gpg --decrypt backup-20240315-encrypted.tar.gz.gpg | \
  tar xzf -
```

### Permissions

```bash
# Restreindre l'accès aux backups
chmod 600 backups/*/*.sql
chmod 700 backups/
```

### Stockage hors site

```bash
# Upload vers S3 (exemple)
aws s3 cp backups/20240315-120000/ \
  s3://my-bucket/openedx-backups/20240315-120000/ \
  --recursive

# Upload vers serveur distant
rsync -avz --progress \
  backups/20240315-120000/ \
  user@backup-server:/backups/openedx/
```

## ⏰ Automatisation

### Cron job pour backups quotidiens

```bash
# Éditer crontab
crontab -e

# Ajouter (backup quotidien à 2h du matin)
0 2 * * * cd /path/to/openedx-native && ./backup-all.sh >> /var/log/openedx-backup.log 2>&1
```

### Script de rotation des backups

```bash
#!/bin/bash
# Garde les 7 derniers backups quotidiens
# Garde les 4 derniers backups hebdomadaires
# Garde les 12 derniers backups mensuels

BACKUP_ROOT="backups"

# Supprimer les backups de plus de 7 jours
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \;

# Créer des backups hebdomadaires (dimanche)
if [ $(date +%u) -eq 7 ]; then
  cp -r "$BACKUP_ROOT/$(ls -t $BACKUP_ROOT | head -1)" \
    "$BACKUP_ROOT/weekly-$(date +%Y%m%d)"
fi

# Créer des backups mensuels (1er du mois)
if [ $(date +%d) -eq 01 ]; then
  cp -r "$BACKUP_ROOT/$(ls -t $BACKUP_ROOT | head -1)" \
    "$BACKUP_ROOT/monthly-$(date +%Y%m)"
fi
```

## 🧪 Test de restore

### Procédure de test mensuelle

1. **Créer un backup test**
```bash
./backup-all.sh
```

2. **Créer un environnement de test**
```bash
# Copier docker-compose.yml
cp docker-compose.yml docker-compose.test.yml

# Modifier les ports et noms de volumes
sed -i 's/openedx_/openedx_test_/g' docker-compose.test.yml
```

3. **Restore dans l'environnement de test**
```bash
docker-compose -f docker-compose.test.yml up -d
./restore-all.sh backups/latest
```

4. **Vérifier le restore**
```bash
# Vérifier les données
docker-compose -f docker-compose.test.yml exec mysql \
  mysql -u root -p -e "SELECT COUNT(*) FROM openedx.auth_user;"

# Tester l'accès
curl http://localhost:8080/health
```

5. **Nettoyer**
```bash
docker-compose -f docker-compose.test.yml down -v
```

## 📊 Monitoring des backups

### Vérification de la taille

```bash
# Taille des backups
du -sh backups/*/

# Tendance de croissance
du -sh backups/*/ | awk '{print $1}' | \
  gnuplot -e "plot '-' with lines"
```

### Alertes

Configurer des alertes si:
- Backup échoue
- Taille du backup augmente de >50% soudainement
- Espace disque < 20%

## 📝 Checklist de backup

- [ ] Backup MySQL créé et vérifié
- [ ] Backup MongoDB créé et vérifié
- [ ] Backup media files créé
- [ ] Backup application data créé
- [ ] Manifest créé avec tailles
- [ ] Backup stocké hors site
- [ ] Backup chiffré (si sensible)
- [ ] Permissions correctes (600/700)
- [ ] Test de restore effectué
- [ ] Documentation à jour

## 🆘 Recovery en cas de désastre

### Scénario: Perte complète du serveur

1. **Provisionner nouveau serveur**
2. **Installer Docker et Docker Compose**
3. **Cloner le repo**
```bash
git clone https://github.com/your-org/edx-platform
cd edx-platform/openedx-native
```

4. **Récupérer les backups**
```bash
# Depuis S3
aws s3 cp s3://my-bucket/openedx-backups/latest/ backups/latest/ --recursive

# Ou depuis serveur distant
rsync -avz user@backup-server:/backups/openedx/latest/ backups/latest/
```

5. **Configurer les variables d'environnement**
```bash
cp .env.example .env
# Éditer .env avec les bonnes valeurs
```

6. **Démarrer les services**
```bash
docker-compose up -d
```

7. **Restore les données**
```bash
./restore-all.sh backups/latest
```

8. **Vérifier**
```bash
./scripts/health-check.sh
```

## 🎓 Ressources

- [MySQL Backup Best Practices](https://dev.mysql.com/doc/refman/8.0/en/backup-and-recovery.html)
- [MongoDB Backup Methods](https://docs.mongodb.com/manual/core/backups/)
- [Docker Volume Backup](https://docs.docker.com/storage/volumes/#backup-restore-or-migrate-data-volumes)
