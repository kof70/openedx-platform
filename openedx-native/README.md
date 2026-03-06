# Open edX Native Docker Compose Setup

Native Docker Compose setup for Open edX without Tutor dependency. This configuration provides a minimal, maintainable deployment for the MVP e-learning platform.

## Overview

This setup replaces the Tutor-based deployment with a direct Docker Compose configuration, reducing complexity while preserving all MVP functionality.

### Architecture

- **LMS**: Learning Management System (learner interface)
- **CMS**: Content Management System (Studio - authoring interface)
- **MySQL 8.4**: Primary relational database
- **MongoDB 7.0**: Content metadata and modulestore
- **Redis 7.4**: Caching, sessions, and Celery message broker
- **Meilisearch 1.8**: Search functionality
- **Caddy 2.7**: Reverse proxy with automatic HTTPS
- **Celery Workers**: Asynchronous task processing (LMS + CMS)

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 8GB RAM minimum
- 50GB disk space

### Initial Setup

1. **Clone and navigate to the setup directory**:
   ```bash
   cd openedx-native
   ```

2. **Create environment file**:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Start services**:
   ```bash
   docker-compose up -d
   ```

4. **Run migrations**:
   ```bash
   docker-compose run --rm lms python manage.py lms migrate --settings=lms.envs.production
   docker-compose run --rm cms python manage.py cms migrate --settings=cms.envs.production
   ```

5. **Collect static files**:
   ```bash
   docker-compose run --rm lms python manage.py lms collectstatic --noinput --settings=lms.envs.production
   docker-compose run --rm cms python manage.py cms collectstatic --noinput --settings=cms.envs.production
   ```

6. **Access the platform**:
   - LMS: https://lms.example.com
   - CMS: https://studio.example.com

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Detailed deployment procedures
- [Configuration Guide](docs/CONFIGURATION.md) - Configuration options
- [Backup & Restore](docs/BACKUP.md) - Backup and restore procedures
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Disabled Features](docs/DISABLED_FEATURES.md) - V2 features disabled for MVP
- [Architecture](docs/ARCHITECTURE.md) - System architecture and design

## Key Features

### MVP Functionality Preserved
- ✅ User authentication and role management
- ✅ Learning paths with prerequisites
- ✅ Content types (pages, videos, PDFs, quizzes, assignments)
- ✅ Pre-test/post-test evaluations
- ✅ PDF certificate generation
- ✅ Reporting and CSV exports
- ✅ Email and announcements
- ✅ FR/EN localization
- ✅ Mobile-first experience

### V2 Features Disabled
- ❌ Forums and discussions
- ❌ SSO providers (Google, Microsoft, SAML)
- ❌ SCORM/xAPI
- ❌ Advanced analytics
- ❌ Video conferencing integrations

See [DISABLED_FEATURES.md](docs/DISABLED_FEATURES.md) for details on re-enabling features.

## Configuration

All configuration is managed through:
- `docker-compose.yml` - Service orchestration
- `.env` - Environment variables and secrets
- `config/lms/` - LMS Django settings
- `config/cms/` - CMS Django settings
- `config/caddy/` - Reverse proxy configuration
- `config/mysql/` - Database optimization

## Maintenance

### View logs
```bash
docker-compose logs -f
```

### Restart services
```bash
docker-compose restart
```

### Backup data
```bash
./scripts/backup.sh
```

### Update configuration
Edit configuration files and restart:
```bash
docker-compose restart lms cms
```

## Support

For issues and questions, refer to:
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Migration Guide](docs/MIGRATION.md) - Migrating from Tutor

## License

This configuration is provided as-is for the MVP e-learning platform deployment.
