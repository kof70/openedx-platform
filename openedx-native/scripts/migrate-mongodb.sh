#!/bin/bash
# MongoDB Migration Script
# Migrates MongoDB database from Tutor to native setup

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="${BACKUP_DIR:-mongo-backup}"
MONGODB_CONTAINER="${MONGODB_CONTAINER:-openedx-mongodb}"
MONGO_DATABASE="${MONGO_DATABASE:-openedx}"
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
    
    if [ ! -d "$BACKUP_DIR" ]; then
        error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    # Check if MongoDB container is running
    if ! docker ps | grep -q "$MONGODB_CONTAINER"; then
        error "MongoDB container not running: $MONGODB_CONTAINER"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Initialize replica set
init_replica_set() {
    log "Initializing MongoDB replica set..."
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would initialize replica set"
        return 0
    fi
    
    # Check if replica set is already initialized
    local rs_status=$(docker exec "$MONGODB_CONTAINER" mongosh --quiet --eval "rs.status().ok" 2>/dev/null || echo "0")
    
    if [ "$rs_status" = "1" ]; then
        log "Replica set already initialized"
        return 0
    fi
    
    # Initialize replica set
    docker exec "$MONGODB_CONTAINER" mongosh --eval "rs.initiate()"
    
    if [ $? -eq 0 ]; then
        log "Replica set initialized successfully"
        sleep 5  # Wait for replica set to be ready
    else
        error "Failed to initialize replica set"
        exit 1
    fi
}

# Copy backup to container
copy_backup() {
    log "Copying backup to MongoDB container..."
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would copy $BACKUP_DIR to container"
        return 0
    fi
    
    docker cp "$BACKUP_DIR" "$MONGODB_CONTAINER:/tmp/"
    
    if [ $? -eq 0 ]; then
        log "Backup copied successfully"
    else
        error "Failed to copy backup to container"
        exit 1
    fi
}

# Restore MongoDB backup
restore_backup() {
    log "Restoring MongoDB backup..."
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would restore backup from /tmp/$(basename $BACKUP_DIR)"
        return 0
    fi
    
    # Restore backup
    docker exec "$MONGODB_CONTAINER" mongorestore --drop "/tmp/$(basename $BACKUP_DIR)"
    
    if [ $? -eq 0 ]; then
        log "MongoDB backup restored successfully"
    else
        error "Failed to restore MongoDB backup"
        exit 1
    fi
}

# Verify data integrity
verify_data() {
    log "Verifying data integrity..."
    
    # List databases
    log "Listing databases..."
    docker exec "$MONGODB_CONTAINER" mongosh --eval "db.adminCommand('listDatabases')"
    
    # Count courses
    local course_count=$(docker exec "$MONGODB_CONTAINER" mongosh "$MONGO_DATABASE" --quiet --eval "db.modulestore.active_versions.countDocuments()" 2>/dev/null || echo "0")
    log "Course count: $course_count"
    
    if [ "$course_count" -eq 0 ]; then
        warning "No courses found in modulestore"
    fi
    
    log "Data verification completed"
}

# Cleanup temporary files
cleanup() {
    log "Cleaning up temporary files..."
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would cleanup /tmp/$(basename $BACKUP_DIR)"
        return 0
    fi
    
    docker exec "$MONGODB_CONTAINER" rm -rf "/tmp/$(basename $BACKUP_DIR)"
    log "Cleanup completed"
}

# Main execution
main() {
    log "Starting MongoDB migration..."
    log "Backup directory: $BACKUP_DIR"
    log "MongoDB container: $MONGODB_CONTAINER"
    log "Database: $MONGO_DATABASE"
    log "Dry run: $DRY_RUN"
    
    check_prerequisites
    init_replica_set
    copy_backup
    restore_backup
    verify_data
    cleanup
    
    log "MongoDB migration completed successfully!"
}

# Run main function
main "$@"
