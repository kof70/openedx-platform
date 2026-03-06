# Tutor to Native Configuration Mapping

## Overview

This document maps Tutor configuration to native Docker Compose configuration, providing a reference for converting settings during migration.

## Environment Variables Mapping

### Database Configuration

| Tutor Variable | Native Variable | Notes |
|----------------|-----------------|-------|
| `MYSQL_ROOT_PASSWORD` | `MYSQL_ROOT_PASSWORD` | Extract from Tutor, regenerate for production |
| Auto-generated | `MYSQL_DATABASE` | Set to `openedx` |
| Auto-generated | `MYSQL_USER` | Set to `openedx` |
| Auto-generated | `MYSQL_PASSWORD` | Generate new secure password |
| Auto-generated | `MONGO_USER` | Set to `openedx` |
| Auto-generated | `MONGO_PASSWORD` | Generate new secure password |
| Auto-generated | `MONGO_DATABASE` | Set to `openedx` |

### Redis Configuration

| Tutor Variable | Native Variable | Notes |
|----------------|-----------------|-------|
| Auto-configured | `REDIS_HOST` | Set to `redis` |
| Auto-configured | `REDIS_PORT` | Set to `6379` |
| Not used | `REDIS_PASSWORD` | Optional, add for security |

### Meilisearch Configuration

| Tutor Variable | Native Variable | Notes |
|----------------|-----------------|-------|
| `MEILI_MASTER_KEY` | `MEILI_MASTER_KEY` | Extract from Tutor: `5oY4nJgUGqnA9eoiXzZftsB6`, regenerate |

### Django Configuration

| Tutor Variable | Native Variable | Notes |
|----------------|-----------------|-------|
| Auto-generated | `SECRET_KEY` | Generate new 50-character random string |
| `LMS_HOST` | `LMS_ROOT_URL` | Format: `https://lms.domain.com` |
| `CMS_HOST` | `CMS_ROOT_URL` | Format: `https://cms.domain.com` |
| `LANGUAGE_CODE` | `LANGUAGE_CODE` | Default: `fr` (French) |
| `TIME_ZONE` | `TIME_ZONE` | Default: `Europe/Paris` |

### SMTP Configuration

| Tutor Variable | Native Variable | Notes |
|----------------|-----------------|-------|
| `SMTP_HOST` | `EMAIL_HOST` | Extract from Tutor config |
| `SMTP_PORT` | `EMAIL_PORT` | Extract from Tutor config |
| `SMTP_USERNAME` | `EMAIL_HOST_USER` | Extract from Tutor config |
| `SMTP_PASSWORD` | `EMAIL_HOST_PASSWORD` | Extract from Tutor config |
| `SMTP_USE_TLS` | `EMAIL_USE_TLS` | Extract from Tutor config |
| `SMTP_USE_SSL` | `EMAIL_USE_SSL` | Extract from Tutor config |

## Django Settings Mapping

### Settings Module Path

```python
# Tutor
DJANGO_SETTINGS_MODULE = "lms.envs.tutor.production"
DJANGO_SETTINGS_MODULE = "cms.envs.tutor.production"

# Native
DJANGO_SETTINGS_MODULE = "lms.envs.production"
DJANGO_SETTINGS_MODULE = "cms.envs.production"
```

### Settings File Location

```
# Tutor
/openedx/edx-platform/lms/envs/tutor/production.py
/openedx/edx-platform/cms/envs/tutor/production.py

# Native
/openedx/config/production.py (mounted from ./config/lms/production.py)
/openedx/config/production.py (mounted from ./config/cms/production.py)
```

### Database Configuration

```python
# Tutor (auto-generated)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('MYSQL_DATABASE'),
        'USER': os.environ.get('MYSQL_USER'),
        'PASSWORD': os.environ.get('MYSQL_PASSWORD'),
        'HOST': 'mysql',
        'PORT': '3306',
        'OPTIONS': {
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}

# Native (explicit in config/lms/common.py)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('MYSQL_DATABASE', 'openedx'),
        'USER': os.environ.get('MYSQL_USER', 'openedx'),
        'PASSWORD': os.environ.get('MYSQL_PASSWORD'),
        'HOST': os.environ.get('MYSQL_HOST', 'mysql'),
        'PORT': os.environ.get('MYSQL_PORT', '3306'),
        'OPTIONS': {
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
            'charset': 'utf8mb4',
        },
        'CONN_MAX_AGE': 60,
    }
}
```

### MongoDB Configuration

```python
# Tutor (auto-generated)
CONTENTSTORE = {
    'ENGINE': 'xmodule.contentstore.mongo.MongoContentStore',
    'DOC_STORE_CONFIG': {
        'host': 'mongodb',
        'port': 27017,
        'db': 'openedx',
        'user': os.environ.get('MONGO_USER'),
        'password': os.environ.get('MONGO_PASSWORD'),
    }
}

# Native (explicit in config/lms/common.py)
CONTENTSTORE = {
    'ENGINE': 'xmodule.contentstore.mongo.MongoContentStore',
    'DOC_STORE_CONFIG': {
        'host': os.environ.get('MONGO_HOST', 'mongodb'),
        'port': int(os.environ.get('MONGO_PORT', 27017)),
        'db': os.environ.get('MONGO_DATABASE', 'openedx'),
        'user': os.environ.get('MONGO_USER'),
        'password': os.environ.get('MONGO_PASSWORD'),
        'replicaSet': 'rs0',
    }
}
```

### Redis Configuration

```python
# Tutor (auto-generated)
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://redis:6379/0',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# Native (explicit in config/lms/common.py)
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': f"redis://{os.environ.get('REDIS_HOST', 'redis')}:{os.environ.get('REDIS_PORT', '6379')}/0",
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {
                'max_connections': 50,
            },
        },
        'KEY_PREFIX': 'openedx',
        'TIMEOUT': 300,
    }
}
```

### Celery Configuration

```python
# Tutor (auto-generated)
CELERY_BROKER_URL = 'redis://redis:6379/0'

# Native (explicit in config/lms/common.py)
CELERY_BROKER_URL = f"redis://{os.environ.get('REDIS_HOST', 'redis')}:{os.environ.get('REDIS_PORT', '6379')}/0"
CELERY_RESULT_BACKEND = CELERY_BROKER_URL
```

## Docker Compose Mapping

### Service Names

| Tutor Service | Native Service | Changes |
|---------------|----------------|---------|
| `mysql` | `mysql` | No change |
| `mongodb` | `mongodb` | No change |
| `redis` | `redis` | Remove static IP |
| `meilisearch` | `meilisearch` | No change |
| `lms` | `lms` | Change settings module |
| `cms` | `cms` | Change settings module |
| `lms-worker` | `lms-worker` | No change |
| `cms-worker` | `cms-worker` | No change |
| `caddy` | `caddy` | Simplify configuration |
| `mfe` | ❌ REMOVED | Not in MVP scope |

### Volume Mapping

| Tutor Volume | Native Volume | Type |
|--------------|---------------|------|
| `./data/mysql` | `mysql_data` | Named volume |
| `./data/mongodb` | `mongo_data` | Named volume |
| `./data/redis` | `redis_data` | Named volume |
| `./data/meilisearch` | `meilisearch_data` | Named volume |
| `./data/openedx-media` | `openedx_media` | Named volume |
| `./data/lms` | `openedx_data` | Named volume |
| `./data/cms` | `openedx_data` | Named volume (shared) |
| `./data/caddy` | `caddy_data` | Named volume |
| N/A | `openedx_static` | Named volume (new) |

### Network Mapping

```yaml
# Tutor
networks:
  openedx-net:
    name: openedx-net
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 10.0.8.0/24

# Native (simplified)
networks:
  openedx:
    name: openedx
    driver: bridge
```

## Feature Flags Mapping

### Features to Disable (V2)

These Tutor features should be disabled in native setup:

```python
# In config/lms/common.py and config/cms/common.py
FEATURES = {
    # Disable V2 features
    'ENABLE_DISCUSSION_SERVICE': False,  # Forums
    'ENABLE_TEAMS': False,  # Teams/community
    'ENABLE_EDXNOTES': False,  # Student notes
    'ENABLE_STUDENT_NOTES': False,
    'ENABLE_THIRD_PARTY_AUTH': False,  # SSO
    'ENABLE_OAUTH2_PROVIDER': False,
    'ENABLE_COMBINED_LOGIN_REGISTRATION': False,
    
    # Keep MVP features
    'CERTIFICATES_HTML_VIEW': True,
    'ENABLE_GRADE_DOWNLOADS': True,
    'ENABLE_INSTRUCTOR_EMAIL': True,
    'ENABLE_COURSE_DISCOVERY': True,
}
```

## Migration Checklist

### Pre-Migration

- [ ] Extract MySQL credentials from Tutor
- [ ] Extract MongoDB credentials from Tutor
- [ ] Extract SMTP configuration from Tutor
- [ ] Extract platform URLs from Tutor
- [ ] Extract Django SECRET_KEY from Tutor
- [ ] Extract Meilisearch MEILI_MASTER_KEY from Tutor
- [ ] Document custom Tutor patches
- [ ] Document installed Tutor plugins

### Configuration Conversion

- [ ] Create .env file with extracted values
- [ ] Generate new production secrets
- [ ] Update Django settings with native paths
- [ ] Update docker-compose.yml with correct domains
- [ ] Update Caddyfile with correct domains
- [ ] Verify all environment variables mapped

### Post-Migration Validation

- [ ] Verify database connectivity
- [ ] Verify Redis connectivity
- [ ] Verify MongoDB connectivity
- [ ] Verify Meilisearch connectivity
- [ ] Test user authentication
- [ ] Test course access
- [ ] Test certificate generation
- [ ] Test email sending

## Extraction Commands

### From Coolify Server

```bash
# Get Tutor config root
tutor config printroot

# Save Tutor configuration
tutor config save --output tutor-config-backup.yml

# Extract environment variables
docker exec openedx-lms env | grep -E "MYSQL|MONGO|REDIS|SECRET|SMTP|EMAIL"

# Get Django settings
docker exec openedx-lms python manage.py lms shell -c "from django.conf import settings; print(settings.DATABASES)"
```

### Generate New Secrets

```bash
# Django SECRET_KEY (50 characters)
openssl rand -base64 50 | tr -d '\n'

# MySQL passwords
openssl rand -base64 32 | tr -d '\n'

# MongoDB passwords
openssl rand -base64 32 | tr -d '\n'

# Meilisearch master key
openssl rand -base64 32 | tr -d '\n'
```

## References

- Tutor Configuration: https://docs.tutor.overhang.io/configuration.html
- Open edX Settings: https://docs.openedx.org/en/latest/developers/references/developer_guide/configuration.html
- Django Settings: https://docs.djangoproject.com/en/3.2/ref/settings/
