#!/bin/bash
#
# Extract Tutor Configuration Script
# 
# This script extracts configuration from the current Tutor deployment
# and prepares it for conversion to native Docker Compose format.
#
# Usage: ./extract-tutor-config.sh [output-dir]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_DIR="${1:-./tutor-config-extracted}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${OUTPUT_DIR}/extraction_${TIMESTAMP}.log"

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"
log "Created output directory: $OUTPUT_DIR"

# Function to check if running on Coolify server
check_environment() {
    log "Checking environment..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found. This script must run on the Coolify server."
        exit 1
    fi
    
    # Check if Tutor containers are running
    if ! docker ps | grep -q "openedx"; then
        warn "No Open edX containers found running. Some extractions may fail."
    fi
    
    log "Environment check passed"
}

# Extract Docker Compose configuration
extract_docker_compose() {
    log "Extracting Docker Compose configuration..."
    
    local compose_file="${OUTPUT_DIR}/docker-compose-tutor.yml"
    
    # Try to find docker-compose.yml
    if [ -f "docker-compose.yml" ]; then
        cp docker-compose.yml "$compose_file"
        log "Copied docker-compose.yml to $compose_file"
    else
        warn "docker-compose.yml not found in current directory"
    fi
}

# Extract environment variables from running containers
extract_env_vars() {
    log "Extracting environment variables from containers..."
    
    local env_file="${OUTPUT_DIR}/tutor-env-vars.txt"
    
    # Extract from LMS container
    if docker ps | grep -q "lms"; then
        log "Extracting from LMS container..."
        docker exec $(docker ps | grep "lms" | grep -v "worker" | awk '{print $1}') env > "$env_file" 2>/dev/null || warn "Failed to extract LMS env vars"
    fi
    
    # Filter sensitive variables
    if [ -f "$env_file" ]; then
        grep -E "MYSQL|MONGO|REDIS|SECRET|SMTP|EMAIL|MEILI|DJANGO|LMS_HOST|CMS_HOST" "$env_file" > "${OUTPUT_DIR}/tutor-env-filtered.txt" || true
        log "Filtered environment variables saved to tutor-env-filtered.txt"
    fi
}

# Extract Django settings
extract_django_settings() {
    log "Extracting Django settings..."
    
    local settings_file="${OUTPUT_DIR}/django-settings.txt"
    
    # Extract DATABASES configuration
    if docker ps | grep -q "lms"; then
        log "Extracting DATABASES configuration..."
        docker exec $(docker ps | grep "lms" | grep -v "worker" | awk '{print $1}') \
            python manage.py lms shell -c "from django.conf import settings; import json; print(json.dumps(dict(settings.DATABASES), indent=2))" \
            > "${OUTPUT_DIR}/databases-config.json" 2>/dev/null || warn "Failed to extract DATABASES config"
        
        # Extract CACHES configuration
        log "Extracting CACHES configuration..."
        docker exec $(docker ps | grep "lms" | grep -v "worker" | awk '{print $1}') \
            python manage.py lms shell -c "from django.conf import settings; import json; print(json.dumps(dict(settings.CACHES), indent=2))" \
            > "${OUTPUT_DIR}/caches-config.json" 2>/dev/null || warn "Failed to extract CACHES config"
        
        # Extract FEATURES configuration
        log "Extracting FEATURES configuration..."
        docker exec $(docker ps | grep "lms" | grep -v "worker" | awk '{print $1}') \
            python manage.py lms shell -c "from django.conf import settings; import json; print(json.dumps(settings.FEATURES, indent=2))" \
            > "${OUTPUT_DIR}/features-config.json" 2>/dev/null || warn "Failed to extract FEATURES config"
    fi
}

# Extract volume information
extract_volumes() {
    log "Extracting volume information..."
    
    local volumes_file="${OUTPUT_DIR}/volumes-info.txt"
    
    # List all volumes
    docker volume ls | grep -E "tutor|openedx" > "$volumes_file" || true
    
    # Get volume details
    for volume in $(docker volume ls -q | grep -E "tutor|openedx"); do
        echo "=== Volume: $volume ===" >> "${OUTPUT_DIR}/volume-details.txt"
        docker volume inspect "$volume" >> "${OUTPUT_DIR}/volume-details.txt" 2>/dev/null || true
        echo "" >> "${OUTPUT_DIR}/volume-details.txt"
    done
    
    log "Volume information saved"
}

# Extract network information
extract_networks() {
    log "Extracting network information..."
    
    local networks_file="${OUTPUT_DIR}/networks-info.txt"
    
    # List networks
    docker network ls | grep -E "tutor|openedx" > "$networks_file" || true
    
    # Get network details
    for network in $(docker network ls -q | xargs docker network inspect | jq -r '.[] | select(.Name | contains("openedx") or contains("tutor")) | .Name'); do
        echo "=== Network: $network ===" >> "${OUTPUT_DIR}/network-details.txt"
        docker network inspect "$network" >> "${OUTPUT_DIR}/network-details.txt" 2>/dev/null || true
        echo "" >> "${OUTPUT_DIR}/network-details.txt"
    done
    
    log "Network information saved"
}

# Extract service status
extract_service_status() {
    log "Extracting service status..."
    
    local status_file="${OUTPUT_DIR}/service-status.txt"
    
    # Get running containers
    docker ps --filter "name=openedx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > "$status_file"
    
    log "Service status saved"
}

# Extract database sizes
extract_database_info() {
    log "Extracting database information..."
    
    # MySQL database size
    if docker ps | grep -q "mysql"; then
        log "Extracting MySQL database sizes..."
        docker exec $(docker ps | grep "mysql" | awk '{print $1}') \
            mysql -u root -p"${MYSQL_ROOT_PASSWORD:-}" -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables GROUP BY table_schema;" \
            > "${OUTPUT_DIR}/mysql-sizes.txt" 2>/dev/null || warn "Failed to extract MySQL sizes (password may be required)"
    fi
    
    # MongoDB database size
    if docker ps | grep -q "mongodb"; then
        log "Extracting MongoDB database sizes..."
        docker exec $(docker ps | grep "mongodb" | awk '{print $1}') \
            mongosh --eval "db.adminCommand('listDatabases')" \
            > "${OUTPUT_DIR}/mongodb-sizes.txt" 2>/dev/null || warn "Failed to extract MongoDB sizes"
    fi
}

# Create conversion template
create_conversion_template() {
    log "Creating conversion template..."
    
    cat > "${OUTPUT_DIR}/conversion-template.env" << 'EOF'
# Native Docker Compose Environment Variables
# Generated from Tutor extraction
# 
# INSTRUCTIONS:
# 1. Fill in the values extracted from Tutor
# 2. Generate new secrets for production
# 3. Copy to openedx-native/.env
# 4. Configure in Coolify UI (do not commit to Git)

# MySQL Configuration
MYSQL_ROOT_PASSWORD=CHANGE_ME_GENERATE_NEW
MYSQL_DATABASE=openedx
MYSQL_USER=openedx
MYSQL_PASSWORD=CHANGE_ME_GENERATE_NEW
MYSQL_HOST=mysql
MYSQL_PORT=3306

# MongoDB Configuration
MONGO_USER=openedx
MONGO_PASSWORD=CHANGE_ME_GENERATE_NEW
MONGO_DATABASE=openedx
MONGO_HOST=mongodb
MONGO_PORT=27017

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Meilisearch Configuration
MEILI_MASTER_KEY=CHANGE_ME_GENERATE_NEW

# Django Configuration
SECRET_KEY=CHANGE_ME_GENERATE_NEW_50_CHARS
LMS_ROOT_URL=https://lms.yourdomain.com
CMS_ROOT_URL=https://cms.yourdomain.com
LANGUAGE_CODE=fr
TIME_ZONE=Europe/Paris

# SMTP Configuration (extract from Tutor)
EMAIL_HOST=smtp.example.com
EMAIL_PORT=587
EMAIL_HOST_USER=user@example.com
EMAIL_HOST_PASSWORD=CHANGE_ME
EMAIL_USE_TLS=true
EMAIL_USE_SSL=false
DEFAULT_FROM_EMAIL=noreply@yourdomain.com

# Feature Flags
ENABLE_CERTIFICATES=true
ENABLE_GRADES=true
ENABLE_COHORTS=true
ENABLE_BULK_EMAIL=true

# Disable V2 Features
ENABLE_DISCUSSION_SERVICE=false
ENABLE_TEAMS=false
ENABLE_THIRD_PARTY_AUTH=false
EOF

    log "Conversion template created: ${OUTPUT_DIR}/conversion-template.env"
}

# Generate extraction report
generate_report() {
    log "Generating extraction report..."
    
    cat > "${OUTPUT_DIR}/EXTRACTION_REPORT.md" << EOF
# Tutor Configuration Extraction Report

**Extraction Date**: $(date)
**Output Directory**: $OUTPUT_DIR

## Extracted Files

- \`docker-compose-tutor.yml\`: Current Tutor docker-compose configuration
- \`tutor-env-vars.txt\`: All environment variables from LMS container
- \`tutor-env-filtered.txt\`: Filtered sensitive environment variables
- \`databases-config.json\`: Django DATABASES configuration
- \`caches-config.json\`: Django CACHES configuration
- \`features-config.json\`: Django FEATURES configuration
- \`volumes-info.txt\`: Docker volumes information
- \`volume-details.txt\`: Detailed volume inspection
- \`networks-info.txt\`: Docker networks information
- \`network-details.txt\`: Detailed network inspection
- \`service-status.txt\`: Current service status
- \`mysql-sizes.txt\`: MySQL database sizes
- \`mongodb-sizes.txt\`: MongoDB database sizes
- \`conversion-template.env\`: Template for native .env file

## Next Steps

1. **Review Extracted Configuration**
   - Check \`tutor-env-filtered.txt\` for sensitive values
   - Review \`databases-config.json\` for database settings
   - Review \`features-config.json\` for enabled features

2. **Create Native .env File**
   - Copy \`conversion-template.env\` to \`openedx-native/.env\`
   - Fill in extracted values
   - Generate new secrets for production
   - Configure in Coolify UI

3. **Verify Mapping**
   - Compare with \`docs/MIGRATION_MAPPING.md\`
   - Ensure all required variables are set
   - Verify database credentials match

4. **Proceed with Migration**
   - Follow \`docs/DEPLOYMENT.md\`
   - Execute backup procedures
   - Run migration scripts

## Security Reminders

⚠️ **CRITICAL**: 
- Never commit the extracted files to Git (they contain secrets)
- Generate new secrets for production
- Store secrets in Coolify environment variables
- Delete extracted files after migration

## References

- Migration Mapping: \`../docs/MIGRATION_MAPPING.md\`
- Deployment Guide: \`../docs/DEPLOYMENT.md\`
- Tutor Audit: \`../docs/TUTOR_AUDIT.md\`
EOF

    log "Extraction report generated: ${OUTPUT_DIR}/EXTRACTION_REPORT.md"
}

# Main execution
main() {
    log "Starting Tutor configuration extraction..."
    log "Output directory: $OUTPUT_DIR"
    
    check_environment
    extract_docker_compose
    extract_env_vars
    extract_django_settings
    extract_volumes
    extract_networks
    extract_service_status
    extract_database_info
    create_conversion_template
    generate_report
    
    log ""
    log "=========================================="
    log "Extraction completed successfully!"
    log "=========================================="
    log ""
    log "Output directory: $OUTPUT_DIR"
    log "Review the EXTRACTION_REPORT.md for next steps"
    log ""
    warn "SECURITY: The extracted files contain secrets. Do not commit to Git!"
}

# Run main function
main "$@"
