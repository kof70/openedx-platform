# Guide de Troubleshooting

Ce guide liste les problèmes courants et leurs solutions pour le setup Open edX natif.

## 🔍 Diagnostic général

### Vérifier l'état des services

```bash
# État de tous les services
docker-compose ps

# Logs de tous les services
docker-compose logs --tail=100

# Logs d'un service spécifique
docker-compose logs -f lms
docker-compose logs -f mysql
```

### Health check complet

```bash
./scripts/health-check.sh
```

## 🚨 Problèmes courants

### 1. Service ne démarre pas

**Symptômes:**
- `docker-compose ps` montre "Exit 1" ou "Restarting"
- Service redémarre en boucle

**Diagnostic:**
```bash
# Voir les logs du service
docker-compose logs --tail=50 lms

# Vérifier les dépendances
docker-compose ps mysql mongodb redis
```

**Solutions:**

#### A. Problème de dépendance
```bash
# Démarrer les services dans l'ordre
docker-compose up -d mysql mongodb redis meilisearch
# Attendre qu'ils soient healthy
sleep 10
docker-compose up -d lms cms
```

#### B. Erreur de configuration
```bash
# Vérifier la syntaxe du fichier de config
python -m py_compile config/lms/production.py

# Vérifier les variables d'environnement
docker-compose config
```

#### C. Problème de permissions
```bash
# Vérifier les permissions des volumes
docker run --rm -v openedx_media:/data alpine ls -lah /data

# Corriger les permissions
docker run --rm -v openedx_media:/data alpine chown -R 1000:1000 /data
```

### 2. MySQL: "Can't connect to MySQL server"

**Symptômes:**
- LMS/CMS ne peuvent pas se connecter à MySQL
- Erreur: `Can't connect to MySQL server on 'mysql'`

**Diagnostic:**
```bash
# Vérifier que MySQL est démarré
docker-compose ps mysql

# Tester la connexion
docker-compose exec mysql mysqladmin ping -h localhost

# Vérifier les logs MySQL
docker-compose logs mysql | grep -i error
```

**Solutions:**

#### A. MySQL pas encore prêt
```bash
# Attendre que MySQL soit ready
docker-compose exec mysql mysqladmin ping -h localhost --wait=30
```

#### B. Mauvais credentials
```bash
# Vérifier les variables d'environnement
docker-compose exec lms env | grep MYSQL

# Vérifier dans MySQL
docker-compose exec mysql mysql -u root -p -e "SELECT user, host FROM mysql.user;"
```

#### C. MySQL crashé
```bash
# Redémarrer MySQL
docker-compose restart mysql

# Si ça ne marche pas, vérifier les logs
docker-compose logs mysql | tail -100
```

### 3. MongoDB: "Replica set not initialized"

**Symptômes:**
- Erreur: `not master and slaveOk=false`
- LMS/CMS ne peuvent pas lire/écrire dans MongoDB

**Diagnostic:**
```bash
# Vérifier le statut du replica set
docker-compose exec mongodb mongosh --eval "rs.status()"
```

**Solutions:**

#### A. Initialiser le replica set
```bash
docker-compose exec mongodb mongosh --eval "rs.initiate()"

# Attendre quelques secondes
sleep 5

# Vérifier
docker-compose exec mongodb mongosh --eval "rs.status().ok"
```

#### B. Replica set corrompu
```bash
# Reconfigurer le replica set
docker-compose exec mongodb mongosh --eval "
  rs.reconfig({
    _id: 'rs0',
    members: [{_id: 0, host: 'mongodb:27017'}]
  }, {force: true})
"
```

### 4. Redis: "Connection refused"

**Symptômes:**
- Erreur: `Error 111 connecting to redis:6379. Connection refused.`
- Cache ne fonctionne pas

**Diagnostic:**
```bash
# Vérifier que Redis est démarré
docker-compose ps redis

# Tester la connexion
docker-compose exec redis redis-cli ping
```

**Solutions:**

#### A. Redis pas démarré
```bash
docker-compose up -d redis
```

#### B. Mauvais mot de passe
```bash
# Vérifier le mot de passe
docker-compose exec redis redis-cli -a "$REDIS_PASSWORD" ping

# Vérifier dans la config LMS
docker-compose exec lms env | grep REDIS
```

### 5. Static files ne se chargent pas

**Symptômes:**
- Page sans CSS/JS
- Erreur 404 sur `/static/*`

**Diagnostic:**
```bash
# Vérifier que les static files existent
docker run --rm -v openedx_static:/data alpine ls -lah /data

# Vérifier les logs Caddy
docker-compose logs caddy | grep static
```

**Solutions:**

#### A. Static files pas collectés
```bash
# Collecter les static files
docker-compose run --rm lms python manage.py lms collectstatic --noinput
docker-compose run --rm cms python manage.py cms collectstatic --noinput

# Redémarrer Caddy
docker-compose restart caddy
```

#### B. Problème de permissions
```bash
# Corriger les permissions
docker run --rm -v openedx_static:/data alpine chown -R 1000:1000 /data
```

#### C. Mauvaise configuration Caddy
```bash
# Vérifier la config Caddy
docker-compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Recharger la config
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### 6. Celery workers ne traitent pas les tâches

**Symptômes:**
- Emails ne sont pas envoyés
- Certificats ne sont pas générés
- Tâches en attente indéfiniment

**Diagnostic:**
```bash
# Vérifier que les workers sont démarrés
docker-compose ps lms-worker cms-worker

# Voir les logs des workers
docker-compose logs -f lms-worker
docker-compose logs -f cms-worker

# Vérifier la connexion Redis
docker-compose exec lms-worker python -c "
from celery import Celery
app = Celery(broker='redis://redis:6379/1')
print(app.control.inspect().active())
"
```

**Solutions:**

#### A. Workers pas démarrés
```bash
docker-compose up -d lms-worker cms-worker
```

#### B. Problème de connexion Redis
```bash
# Vérifier la config Celery
docker-compose exec lms env | grep CELERY

# Redémarrer Redis et workers
docker-compose restart redis lms-worker cms-worker
```

#### C. Tâches bloquées
```bash
# Purger la queue
docker-compose exec redis redis-cli -a "$REDIS_PASSWORD" FLUSHDB

# Redémarrer les workers
docker-compose restart lms-worker cms-worker
```

### 7. Migrations échouent

**Symptômes:**
- Erreur lors de `manage.py migrate`
- Base de données pas à jour

**Diagnostic:**
```bash
# Voir les migrations appliquées
docker-compose run --rm lms python manage.py lms showmigrations

# Voir les erreurs
docker-compose run --rm lms python manage.py lms migrate --verbosity=2
```

**Solutions:**

#### A. Migration conflictuelle
```bash
# Identifier la migration problématique
docker-compose run --rm lms python manage.py lms showmigrations | grep "\[ \]"

# Appliquer manuellement
docker-compose run --rm lms python manage.py lms migrate app_name migration_name
```

#### B. Base de données corrompue
```bash
# Backup d'abord !
docker-compose exec mysql mysqldump -u root -p openedx > backup.sql

# Réinitialiser les migrations (DANGER)
docker-compose run --rm lms python manage.py lms migrate --fake app_name zero
docker-compose run --rm lms python manage.py lms migrate app_name
```

### 8. Erreur 500 sur le LMS/CMS

**Symptômes:**
- Page d'erreur 500
- "Internal Server Error"

**Diagnostic:**
```bash
# Voir les logs Django
docker-compose logs lms | grep -i error
docker-compose logs lms | grep -i exception

# Activer le mode DEBUG (temporairement)
# Dans config/lms/production.py: DEBUG = True
docker-compose restart lms
```

**Solutions:**

#### A. Erreur de configuration
```bash
# Vérifier la syntaxe Python
python -m py_compile config/lms/production.py

# Vérifier les imports
docker-compose run --rm lms python -c "
import sys
sys.path.insert(0, '/openedx/edx-platform')
from lms.envs.production import *
print('Config OK')
"
```

#### B. Problème de base de données
```bash
# Vérifier la connexion
docker-compose exec lms python manage.py lms check --database default

# Vérifier les migrations
docker-compose run --rm lms python manage.py lms showmigrations | grep "\[ \]"
```

### 9. Mémoire insuffisante

**Symptômes:**
- Services killed par OOM
- Serveur lent
- `docker-compose ps` montre "Exit 137"

**Diagnostic:**
```bash
# Voir l'utilisation mémoire
docker stats --no-stream

# Voir les logs système
dmesg | grep -i "out of memory"
```

**Solutions:**

#### A. Augmenter la mémoire Docker
```bash
# Dans docker-compose.yml, ajouter des limites
services:
  lms:
    mem_limit: 2g
    mem_reservation: 1g
```

#### B. Optimiser les services
```bash
# Réduire les workers Celery
# Dans docker-compose.yml:
command: celery -A lms.celery worker --concurrency=2

# Optimiser MySQL
# Dans config/mysql/my.cnf:
innodb_buffer_pool_size = 512M
```

#### C. Ajouter du swap
```bash
# Sur le serveur
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 10. HTTPS ne fonctionne pas

**Symptômes:**
- Certificat SSL invalide
- Redirection HTTP → HTTPS ne marche pas

**Diagnostic:**
```bash
# Vérifier les logs Caddy
docker-compose logs caddy | grep -i certificate
docker-compose logs caddy | grep -i tls

# Tester HTTPS
curl -I https://lms.coolify.alonu.shop
```

**Solutions:**

#### A. Problème Let's Encrypt
```bash
# Vérifier que le domaine pointe vers le serveur
dig lms.coolify.alonu.shop

# Vérifier que le port 443 est ouvert
sudo netstat -tlnp | grep :443

# Forcer le renouvellement
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

#### B. Configuration Caddy incorrecte
```bash
# Valider la config
docker-compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Voir la config active
docker-compose exec caddy caddy adapt --config /etc/caddy/Caddyfile
```

## 🔧 Outils de diagnostic

### Script de diagnostic complet

```bash
#!/bin/bash
# diagnostic.sh - Collecte d'informations pour le troubleshooting

echo "=== Docker Compose Status ==="
docker-compose ps

echo -e "\n=== Service Logs (last 50 lines) ==="
for service in mysql mongodb redis meilisearch lms cms lms-worker cms-worker caddy; do
  echo "--- $service ---"
  docker-compose logs --tail=50 $service 2>&1 | tail -20
done

echo -e "\n=== Resource Usage ==="
docker stats --no-stream

echo -e "\n=== Disk Usage ==="
df -h

echo -e "\n=== Volume Sizes ==="
docker system df -v | grep openedx

echo -e "\n=== Network Connectivity ==="
docker-compose exec lms ping -c 3 mysql || echo "Cannot reach MySQL"
docker-compose exec lms ping -c 3 mongodb || echo "Cannot reach MongoDB"
docker-compose exec lms ping -c 3 redis || echo "Cannot reach Redis"

echo -e "\n=== Database Connectivity ==="
docker-compose exec mysql mysqladmin ping -h localhost || echo "MySQL not responding"
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')" || echo "MongoDB not responding"
docker-compose exec redis redis-cli ping || echo "Redis not responding"
```

### Activer le mode debug

```python
# config/lms/production.py (temporairement)
DEBUG = True
ALLOWED_HOSTS = ['*']

# Logging détaillé
LOGGING['handlers']['console']['level'] = 'DEBUG'
LOGGING['loggers']['django']['level'] = 'DEBUG'
```

**⚠️ Ne jamais laisser DEBUG=True en production !**

## 📞 Obtenir de l'aide

### Informations à fournir

Lors d'une demande d'aide, fournir:

1. **Logs des services concernés**
```bash
docker-compose logs --tail=200 lms > lms-logs.txt
```

2. **État des services**
```bash
docker-compose ps > services-status.txt
```

3. **Configuration (sans secrets)**
```bash
docker-compose config > config-sanitized.yml
```

4. **Résultat du health check**
```bash
./scripts/health-check.sh > health-check.txt
```

5. **Description du problème**
- Quand est-ce arrivé ?
- Qu'est-ce qui a changé récemment ?
- Étapes pour reproduire

## 🎓 Ressources

- [Docker Compose Troubleshooting](https://docs.docker.com/compose/faq/)
- [Open edX Troubleshooting](https://docs.openedx.org/en/latest/developers/references/troubleshooting.html)
- [MySQL Error Messages](https://dev.mysql.com/doc/mysql-errors/8.0/en/)
- [MongoDB Troubleshooting](https://docs.mongodb.com/manual/faq/diagnostics/)
