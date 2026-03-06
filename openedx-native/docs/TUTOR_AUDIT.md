# Tutor Setup Audit

## Overview

This document captures the current Tutor-based Open edX deployment configuration on Coolify, serving as the baseline for migration to native Docker Compose.

**Audit Date**: 2026-03-06  
**Coolify Service UUID**: o0kwks04kcg0gk484c8owkws  
**Environment**: Production

## Current Architecture

### Services Running

Based on the Tutor docker-compose configuration, the following services are deployed:

1. **Caddy** (Reverse Proxy)
   - Image: `docker.io/caddy:2.7.4`
   - Purpose: HTTPS termination and routing
   - Configuration: `./env/apps/caddy/Caddyfile`
   - Data: `./data/caddy`

2. **LMS** (Learning Management System)
   - Image: `docker.io/overhangio/openedx:21.0.1-indigo`
   - Environment: `SERVICE_VARIANT=lms`
   - Settings: `DJANGO_SETTINGS_MODULE=lms.envs.tutor.production`
   - Session Cookie Domain: `coolify.alonu.shop`
   - MFE Config Domain: `.coolify.alonu.shop`

3. **CMS** (Content Management System / Studio)
   - Image: `docker.io/overhangio/openedx:21.0.1-indigo`
   - Environment: `SERVICE_VARIANT=cms`
   - Settings: `DJANGO_SETTINGS_MODULE=cms.envs.tutor.production`
   - Depends on: LMS

4. **MySQL 8.4.0**
   - Image: `docker.io/mysql:8.4.0`
   - Root Password: `Hwn2iv1t` (CHANGE IN PRODUCTION)
   - Character Set: `utf8mb4`
   - Native Password: ON
   - Data: `./data/mysql`

5. **Redis 7.4.5**
   - Image: `docker.io/redis:7.4.5`
   - Static IP: `10.0.8.100` (in openedx-net)
   - Purpose: Caching, sessions, Celery broker

6. **MongoDB 7.0.28**
   - Image: `docker.io/mongo:7.0.28`
   - Purpose: Course content storage (modulestore)
   - Data: Managed by Tutor

7. **Meilisearch 1.8.4**
   - Image: `docker.io/getmeili/meilisearch:v1.8.4`
   - Master Key: `5oY4nJgUGqnA9eoiXzZftsB6` (CHANGE IN PRODUCTION)
   - Data: `./data/meilisearch`

8. **MFE** (Micro-Frontend)
   - Image: `docker.io/overhangio/openedx-mfe:21.0.0-indigo`
   - Command: `caddy run --config /etc/caddy/Caddyfile --adapter caddyfile`
   - Configuration: `./env/plugins/mfe/apps/mfe/Caddyfile`
   - Depends on: LMS

9. **LMS Worker** (Celery)
   - Image: `docker.io/overhangio/openedx:21.0.1-indigo`
   - Command: `celery --app=lms.celery worker --loglevel=info`
   - Environment: `SERVICE_VARIANT=lms`
   - Depends on: LMS

10. **CMS Worker** (Celery)
    - Image: `docker.io/overhangio/openedx:21.0.1-indigo`
    - Command: `celery --app=cms.celery worker --loglevel=info`
    - Environment: `SERVICE_VARIANT=cms`
    - Depends on: CMS

### Network Configuration

- **Network Name**: `openedx-net`
- **Driver**: bridge
- **Subnet**: `10.0.8.0/24`
- **Static IPs**: Redis has static IP `10.0.8.100`

### Volume Mounts

#### LMS Volumes
```
./env/apps/openedx/settings/lms:/openedx/edx-platform/lms/envs/tutor:ro
./env/apps/openedx/settings/cms:/openedx/edx-platform/cms/envs/tutor:ro
./env/apps/openedx/config:/openedx/config:ro
./env/apps/openedx/uwsgi.ini:/openedx/uwsgi.ini:ro
./data/lms:/openedx/data
./data/openedx-media:/openedx/media
```

#### CMS Volumes
```
./env/apps/openedx/settings/lms:/openedx/edx-platform/lms/envs/tutor:ro
./env/apps/openedx/settings/cms:/openedx/edx-platform/cms/envs/tutor:ro
./env/apps/openedx/config:/openedx/config:ro
./env/apps/openedx/uwsgi.ini:/openedx/uwsgi.ini:ro
./data/cms:/openedx/data
./data/openedx-media:/openedx/media
```

#### Infrastructure Volumes
- MySQL: `./data/mysql:/var/lib/mysql`
- Meilisearch: `./data/meilisearch:/meili_data`
- Caddy: `./data/caddy:/data`

### Key Configuration Files

1. **Django Settings**
   - LMS: `./env/apps/openedx/settings/lms/` (Tutor-managed)
   - CMS: `./env/apps/openedx/settings/cms/` (Tutor-managed)
   - Settings Module: `tutor.production`

2. **uWSGI Configuration**
   - Path: `./env/apps/openedx/uwsgi.ini`
   - Shared between LMS and CMS

3. **Caddy Configuration**
   - Main: `./env/apps/caddy/Caddyfile`
   - MFE: `./env/plugins/mfe/apps/mfe/Caddyfile`

4. **Open edX Config**
   - Path: `./env/apps/openedx/config/`
   - Contains: lms.yml, cms.yml, and other Open edX configs

## Tutor-Specific Features

### Settings Path Convention
- Tutor uses: `lms.envs.tutor.production` and `cms.envs.tutor.production`
- Native will use: `lms.envs.production` and `cms.envs.production`

### Automatic Configuration Generation
Tutor automatically generates:
- Django settings files
- uWSGI configuration
- Caddy reverse proxy configuration
- Database initialization scripts
- Secret keys and passwords

### Plugins System
Tutor plugins may be installed. Check with:
```bash
tutor plugins list
```

### Patches System
Tutor allows patching configuration files. Check:
```bash
tutor config printroot
# Look for patches/ directory
```

## Data to Migrate

### 1. MySQL Database
- **Location**: `./data/mysql/`
- **Database Name**: To be determined from Tutor config
- **Tables**: User accounts, enrollments, grades, certificates, etc.
- **Estimated Size**: To be measured during backup

### 2. MongoDB Database
- **Location**: Managed by Tutor
- **Database Name**: Typically `openedx`
- **Collections**: Course content, modulestore
- **Estimated Size**: To be measured during backup

### 3. Media Files
- **Location**: `./data/openedx-media/`
- **Contents**: User uploads, course assets, profile images
- **Estimated Size**: To be measured during backup

### 4. Application Data
- **LMS Data**: `./data/lms/`
- **CMS Data**: `./data/cms/`
- **Contents**: Logs, temporary files, application state

### 5. Meilisearch Index
- **Location**: `./data/meilisearch/`
- **Contents**: Search indices
- **Note**: Can be rebuilt after migration

## Configuration Extraction Needed

### From Tutor Config
The following need to be extracted from Tutor configuration:

1. **Database Credentials**
   - MySQL root password
   - MySQL user/password
   - MongoDB credentials

2. **Secret Keys**
   - Django SECRET_KEY
   - Meilisearch MEILI_MASTER_KEY

3. **SMTP Configuration**
   - SMTP host, port, user, password
   - Email backend settings

4. **Platform URLs**
   - LMS_ROOT_URL
   - CMS_ROOT_URL
   - Domain configuration

5. **Feature Flags**
   - Enabled/disabled features
   - Custom feature configurations

6. **Third-Party Integrations**
   - Storage backends (S3, etc.)
   - Analytics integrations
   - Payment gateways

## Migration Considerations

### Services to Remove
- **MFE service**: Not in MVP scope (V2 feature)
- MFE Caddyfile configuration

### Services to Keep
All other services map 1:1 to native setup:
- MySQL 8.4 → MySQL 8.4 ✓
- MongoDB 7.0 → MongoDB 7.0 ✓
- Redis 7.4 → Redis 7.4 ✓
- Meilisearch 1.8 → Meilisearch 1.8 ✓
- LMS → LMS ✓
- CMS → CMS ✓
- LMS Worker → LMS Worker ✓
- CMS Worker → CMS Worker ✓
- Caddy → Caddy ✓

### Configuration Changes Required

1. **Django Settings Module**
   - From: `lms.envs.tutor.production`
   - To: `lms.envs.production`

2. **Settings File Location**
   - From: `/openedx/edx-platform/lms/envs/tutor/`
   - To: `/openedx/config/` (mounted from `./config/lms/`)

3. **Network Configuration**
   - Remove static IP for Redis (not needed)
   - Keep bridge network

4. **Volume Structure**
   - Consolidate to named volumes
   - Simplify mount paths

## Next Steps

1. **Task 11**: Create comprehensive backup
   - Backup MySQL database
   - Backup MongoDB database
   - Backup media files
   - Backup application data
   - Verify backup integrity

2. **Task 12**: Convert Tutor configuration to native
   - Extract secrets from Tutor config
   - Map Django settings
   - Create .env file
   - Document configuration mapping

3. **Task 13**: Create migration scripts (COMPLETED)
   - Migration scripts already created
   - Ready for execution

## Security Notes

⚠️ **CRITICAL**: The following secrets are visible in the docker-compose.yml and MUST be changed:
- MySQL root password: `Hwn2iv1t`
- Meilisearch master key: `5oY4nJgUGqnA9eoiXzZftsB6`

These should be:
1. Extracted and stored securely
2. Regenerated for production
3. Configured in Coolify environment variables
4. Never committed to Git

## References

- Tutor Documentation: https://docs.tutor.overhang.io/
- Open edX Documentation: https://docs.openedx.org/
- Migration Design: `../design.md`
- Migration Scripts: `../scripts/`
