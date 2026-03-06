#!/bin/bash
# Media Files Migration Script
# Migrates media files and application data from Tutor to native setup

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MEDIA_BACKUP_DIR="${MEDIA_BACKUP_DIR:-media-backup}"
DATA_BACKUP_DIR="${DATA_BACKUP_DIR:-data-backup}"
MEDIA_VOLUME="${MEDIA_VOLUME:-openedx_media}"
DATA_VOLUME="${DATA_VOLUME:-openedx_data}"
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
    
    if [ ! -d "$MEDIA_BACKUP_DIR" ]; then
        error "Media backup directory not found: $MEDIA_BACKUP_DIR"
        exit 1
    fi
    
    if [ ! -d "$DATA_BACKUP_DIR" ]; then
        error "Data backup directory not found: $DATA_BACKUP_DIR"
        exit 1
    fi
    
    # Check if volumes exist
    if ! docker volume ls | grep -q "$MEDIA_VOLUME"; then
        error "Media volume not found: $MEDIA_VOLUME"
        exit 1
    fi
    
    if ! docker volume ls | grep -q "$DATA_VOLUME"; then
        error "Data volume not found: $DATA_VOLUME"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

# Migrate media files
migrate_media() {
    log "Migrating media files..."
    
    local media_size=$(du -sh "$MEDIA_BACKUP_DIR" | cut -f1)
    log "Media backup size: $media_size"
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would copy $MEDIA_BACKUP_DIR to $MEDIA_VOLUME"
        return 0
    fi
    
    # Copy media files to volume
    docker run --rm \
        -v "$MEDIA_VOLUME:/target" \
        -v "$(pwd)/$MEDIA_BACKUP_DIR:/source:ro" \
        alpine \
        sh -c "cp -a /source/. /target/ && chown -R 1000:1000 /target"
    
    if [ $? -eq 0 ]; then
        log "Media files migrated successfully"
    else
        error "Failed to migrate media files"
        exit 1
    fi
}

# Migrate application data
migrate_data() {
    log "Migrating application data..."
    
    local data_size=$(du -sh "$DATA_BACKUP_DIR" | cut -f1)
    log "Data backup size: $data_size"
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would copy $DATA_BACKUP_DIR to $DATA_VOLUME"
        return 0
    fi
    
    # Copy application data to volume
    docker run --rm \
        -v "$DATA_VOLUME:/target" \
        -v "$(pwd)/$DATA_BACKUP_DIR:/source:ro" \
        alpine \
        sh -c "cp -a /source/. /target/ && chown -R 1000:1000 /target"
    
    if [ $? -eq 0 ]; then
        log "Application data migrated successfully"
    else
        error "Failed to migrate application data"
        exit 1
    fi
}

# Verify migration
verify_migration() {
    log "Verifying migration..."
    
    # Verify media files
    log "Media files:"
    docker run --rm -v "$MEDIA_VOLUME:/data" alpine ls -lah /data | head -20
    
    local media_file_count=$(docker run --rm -v "$MEDIA_VOLUME:/data" alpine find /data -type f | wc -l)
    log "Media file count: $media_file_count"
    
    # Verify application data
    log "Application data:"
    docker run --rm -v "$DATA_VOLUME:/data" alpine ls -lah /data | head -20
    
    local data_file_count=$(docker run --rm -v "$DATA_VOLUME:/data" alpine find /data -type f | wc -l)
    log "Data file count: $data_file_count"
    
    log "Verification completed"
}

# Main execution
main() {
    log "Starting media files migration..."
    log "Media backup: $MEDIA_BACKUP_DIR"
    log "Data backup: $DATA_BACKUP_DIR"
    log "Media volume: $MEDIA_VOLUME"
    log "Data volume: $DATA_VOLUME"
    log "Dry run: $DRY_RUN"
    
    check_prerequisites
    migrate_media
    migrate_data
    verify_migration
    
    log "Media files migration completed successfully!"
}

# Run main function
main "$@"
