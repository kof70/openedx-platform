#!/bin/bash
# MySQL Migration Script
# Migrates MySQL database from Tutor to native setup

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKUP_FILE="${BACKUP_FILE:-mysql-backup.sql}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-openedx-mysql}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
DRY_RUN="${DRY_RUN:-false}"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if [ ! -f "$BACKUP_FILE" ]; then
        error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        error "MYSQL_ROOT_PASSWORD environment variable not set"
        exit 1
    fi
    
    # Check if MySQL container is running
    if ! docker ps | grep -q "$MYSQL_CONTAINER"; then
        error "MySQL container not running: $MYSQL_CONTAINER"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Verify backup file
verify_backup() {
    log "Verifying backup file..."
    
    if [ ! -s "$BACKUP_FILE" ]; then
        error "Backup file is empty"
        exit 1
    fi
    
    if ! grep -q "CREATE TABLE" "$BACKUP_FILE"; then
        error "Backup file does not contain valid SQL"
        exit 1
    fi
    
    local backup_size=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup file size: $backup_size"
    log "Backup verification passed"
}

# Import MySQL backup
import_backup() {
    log "Importing MySQL backup..."
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would import $BACKUP_FILE to $MYSQL_CONTAINER"
        return 0
    fi
    
    # Import backup
    docker exec -i "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "$BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        log "MySQL backup imported successfully"
    else
        error "Failed to import MySQL backup"
        exit 1
    fi
}

# Verify data integrity
verify_data() {
    log "Verifying data integrity..."
    
    # Count users
    local user_count=$(docker exec "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM openedx.auth_user;" 2>/dev/null || echo "0")
    log "User count: $user_count"
    
    # Count enrollments
    local enrollment_count=$(docker exec "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM openedx.student_courseenrollment;" 2>/dev/null || echo "0")
    log "Enrollment count: $enrollment_count"
    
    # Count certificates
    local cert_count=$(docker exec "$MYSQL_CONTAINER" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM openedx.certificates_generatedcertificate;" 2>/dev/null || echo "0")
    log "Certificate count: $cert_count"
    
    if [ "$user_count" -eq 0 ]; then
        warning "No users found in database"
    fi
    
    log "Data verification completed"
}

# Main execution
main() {
    log "Starting MySQL migration..."
    log "Backup file: $BACKUP_FILE"
    log "MySQL container: $MYSQL_CONTAINER"
    log "Dry run: $DRY_RUN"
    
    check_prerequisites
    verify_backup
    import_backup
    verify_data
    
    log "MySQL migration completed successfully!"
}

# Run main function
main "$@"
