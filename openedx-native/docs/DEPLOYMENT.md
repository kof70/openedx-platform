# Guide de déploiement sur Coolify

Ce guide explique comment déployer le setup Open edX natif sur Coolify.

## 📋 Prérequis

- Accès à Coolify avec permissions de déploiement
- Repo GitHub avec le code Open edX et la config native
- Serveur Coolify avec Docker installé
- Backups Tutor disponibles (si migration)

## 🎯 Stratégie de déploiement

### Option A: Nouveau service (recommandé pour test)

Créer un nouveau service Coolify à côté de l'ancien service Tutor.

**Avantages:**
- ✅ Ancien service reste actif
- ✅ Test sans risque
- ✅ Rollback immédiat
- ✅ Comparaison des performances

**Inconvénients:**
- ⚠️ Utilise plus de ressources serveur
- ⚠️ Nécessite des domaines différents

### Option B: Remplacement direct

Remplacer le service Tutor existant par le setup natif.

**Avantages:**
- ✅ Pas de duplication de ressources
- ✅ Mêmes domaines

**Inconvénients:**
- ⚠️ Downtime pendant la migration
- ⚠️ Rollback plus complexe

## 🚀 Déploiement - Option A (Nouveau service)

### Étape 1: Préparer le repo

```bash
# S'assurer que tous les fichiers sont commités
cd openedx-platform
git add openedx-native/
git commit -m "Add native Docker Compose setup"
git push origin main
```

### Étape 2: Créer le service dans Coolify

#### Via l'interface Coolify:

1. **Aller dans votre projet** (ex: "2026")
2. **Cliquer sur "New Resource"**
3. **Sélectionner "Docker Compose"**
4. **Configuration:**
   - Name: `openedx-native`
   - Git Repository: `https://github.com/your-org/edx-platform`
   - Branch: `main`
   - Docker Compose Location: `openedx-native/docker-compose.yml`
   - Build Pack: `docker-compose`

#### Via MCP (API):

```javascript
// Créer le service
mcp_coolify_alonu_create_dockercompose_application({
  project_uuid: "...",
  environment_name: "production",
  server_uuid: "...",
  docker_compose_raw: "<base64 du docker-compose.yml>",
  instant_deploy: false
})
```

### Étape 3: Configurer les variables d'environnement

Dans Coolify UI, aller dans le service → "Environment Variables":

```bash
# MySQL
MYSQL_ROOT_PASSWORD=<generate-strong-password>
MYSQL_DATABASE=openedx
MYSQL_USER=openedx
MYSQL_PASSWORD=<generate-strong-password>

# MongoDB
MONGO_DATABASE=openedx
MONGO_USER=openedx
MONGO_PASSWORD=<generate-strong-password>

# Redis
REDIS_PASSWORD=<generate-strong-password>

# Meilisearch
MEILI_MASTER_KEY=<generate-strong-password>

# Django
SECRET_KEY=<generate-django-secret-key>
ALLOWED_HOSTS=lms-native.coolify.alonu.shop,studio-native.coolify.alonu.shop

# Email (SMTP)
EMAIL_HOST=smtp.example.com
EMAIL_PORT=587
EMAIL_HOST_USER=noreply@example.com
EMAIL_HOST_PASSWORD=<smtp-password>
EMAIL_USE_TLS=true

# Localization
LANGUAGE_CODE=fr
TIME_ZONE=Europe/Paris

# Platform URLs
LMS_ROOT_URL=https://lms-native.coolify.alonu.shop
CMS_ROOT_URL=https://studio-native.coolify.alonu.shop

# Feature flags
ENABLE_CERTIFICATES=true
ENABLE_COHORTS=true
ENABLE_BULK_EMAIL=true
```

### Étape 4: Configurer les domaines

Dans Coolify UI, aller dans le service → "Domains":

- **LMS**: `lms-native.coolify.alonu.shop`
- **CMS**: `studio-native.coolify.alonu.shop`

Coolify configurera automatiquement:
- ✅ Certificats SSL (Let's Encrypt)
- ✅ Reverse proxy (Traefik)
- ✅ Redirection HTTP → HTTPS

### Étape 5: Déployer le service

```bash
# Via Coolify UI
# Cliquer sur "Deploy"

# Via MCP (API)
mcp_coolify_alonu_deploy({
  uuid: "...",
  force: false
})
```

### Étape 6: Migrer les données

Une fois le service déployé, migrer les données depuis Tutor:

```bash
# Se connecter au serveur Coolify via SSH
ssh user@coolify-server

# Aller dans le répertoire du service
cd /path/to/openedx-native

# Copier les backups Tutor
# (depuis le service Tutor existant)

# Exécuter la migration
export MYSQL_ROOT_PASSWORD="your-password"
./scripts/migrate-with-rollback.sh
```

### Étape 7: Vérifier la santé

```bash
# Sur le serveur Coolify
./scripts/health-check.sh

# Ou via navigateur
https://lms-native.coolify.alonu.shop/health
https://studio-native.coolify.alonu.shop/health
```

### Étape 8: Tests fonctionnels

1. **Login**: Tester avec un compte existant
2. **Cours**: Accéder à un cours existant
3. **Contenu**: Vérifier que le contenu s'affiche
4. **Certificats**: Générer un certificat test
5. **Email**: Envoyer un email test

### Étape 9: Basculement (si tout OK)

Une fois le nouveau service validé:

1. **Mettre à jour les DNS** pour pointer vers le nouveau service
2. **Arrêter l'ancien service Tutor** (mais le garder pour rollback)
3. **Monitorer** le nouveau service pendant 24-48h

## 🔄 Déploiement - Option B (Remplacement)

### Étape 1: Planifier la maintenance

- Annoncer une fenêtre de maintenance
- Prévoir 2-4 heures de downtime
- Avoir un plan de rollback

### Étape 2: Backup complet

```bash
# Sur le serveur Coolify
cd /path/to/tutor-service

# Backup MySQL
docker exec tutor-mysql mysqldump --all-databases > mysql-backup.sql

# Backup MongoDB
docker exec tutor-mongodb mongodump --out=/tmp/mongo-backup
docker cp tutor-mongodb:/tmp/mongo-backup ./mongo-backup

# Backup media
docker cp tutor-lms:/openedx/media ./media-backup
docker cp tutor-cms:/openedx/data ./data-backup
```

### Étape 3: Arrêter Tutor

```bash
# Arrêter le service Tutor dans Coolify
# Via UI: Service → Stop

# Via MCP
mcp_coolify_alonu_stop_service({
  uuid: "o0kwks04kcg0gk484c8owkws",
  confirm: true
})
```

### Étape 4: Déployer le setup natif

Suivre les étapes 1-7 de l'Option A, mais utiliser les mêmes domaines:
- `lms.coolify.alonu.shop`
- `studio.coolify.alonu.shop`

### Étape 5: Migrer les données

```bash
export MYSQL_ROOT_PASSWORD="your-password"
./scripts/migrate-with-rollback.sh
```

### Étape 6: Vérifier et ouvrir

```bash
./scripts/health-check.sh
```

Si tout est OK, annoncer la fin de la maintenance.

## 🔧 Mises à jour après déploiement

### Mise à jour de configuration

```bash
# Modifier localement
vim openedx-native/config/lms/production.py

# Commit et push
git add openedx-native/config/
git commit -m "Config: update feature flags"
git push origin main

# Coolify redéploie automatiquement
# Ou manuellement via UI: Deploy
```

### Mise à jour de code Open edX

```bash
# Modifier le code
vim lms/djangoapps/...

# Commit et push
git add lms/
git commit -m "Fix: certificate generation"
git push origin main

# Coolify rebuild + redéploie
```

### Mise à jour des secrets

Via Coolify UI → Service → Environment Variables → Modifier → Save → Redeploy

## 📊 Monitoring

### Logs

```bash
# Via Coolify UI
Service → Logs

# Via SSH sur le serveur
docker-compose logs -f
docker-compose logs -f lms
docker-compose logs -f mysql
```

### Métriques

```bash
# Utilisation des ressources
docker stats

# Santé des services
./scripts/health-check.sh
```

### Alertes

Configurer des alertes Coolify pour:
- Service down
- Utilisation CPU > 80%
- Utilisation mémoire > 80%
- Erreurs dans les logs

## 🆘 Rollback

### Si problème avec le nouveau service (Option A)

```bash
# Simplement revenir à l'ancien service Tutor
# Via DNS ou Coolify routing
```

### Si problème après remplacement (Option B)

```bash
# Sur le serveur
cd /path/to/openedx-native
./scripts/rollback.sh

# Redémarrer Tutor manuellement
# Via Coolify UI: Start service
```

## 🔒 Sécurité

### Secrets

- ✅ Tous les secrets dans Coolify UI (pas dans Git)
- ✅ Rotation régulière des mots de passe
- ✅ Accès SSH limité au serveur

### Réseau

- ✅ Seuls ports 80/443 exposés
- ✅ Services internes sur réseau Docker privé
- ✅ Firewall configuré sur le serveur

### Backups

- ✅ Backups automatiques quotidiens
- ✅ Rétention 30 jours
- ✅ Stockage hors serveur

## 📝 Checklist de déploiement

- [ ] Repo GitHub à jour avec config native
- [ ] Variables d'environnement configurées dans Coolify
- [ ] Domaines configurés et DNS pointant vers Coolify
- [ ] Backups Tutor créés et vérifiés
- [ ] Service Coolify créé et configuré
- [ ] Premier déploiement réussi
- [ ] Migration des données effectuée
- [ ] Health checks passent
- [ ] Tests fonctionnels OK
- [ ] Monitoring configuré
- [ ] Plan de rollback testé
- [ ] Documentation à jour

## 🎓 Ressources

- [Documentation Coolify](https://coolify.io/docs)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Open edX Documentation](https://docs.openedx.org/)
