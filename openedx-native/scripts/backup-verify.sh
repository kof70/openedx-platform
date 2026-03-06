#!/bin/bash
# Backup Verification Script
# Verifies integrity of backup files before migration

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MYSQL_BACKUP="${MYSQL_BACKUP:-mysql-backup.sql}"
MONGO_BACKUP_DIR="${MONGO_BACKUP_DIR:-mongo-backup}"
MEDIA_BACKUP_DIR="${MEDIA_BACKUP_DIR:-media-backup}"
DATA_BACKUP_DIR="${DATA_BACKUP_DIR:-data-backup}"

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

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Verify MySQL backup
verify_mysql() {
    log "Verifying MySQL backup..."
    
    if [ ! -f "$MYSQL_BACKUP" ]; then
        error "MySQL backup file not found: $MYSQL_BACKUP"
        return 1
    fi
    
    if [ ! -s "$MYSQL_BACKUP" ]; then
        error "MySQL backup file is empty"
        return 1
    fi
    
    if ! grep -q "CREATE TABLE" "$MYSQL_BACKUP"; then
        error "MySQL backup does not contain valid SQL"
        return 1
    fi
    
    local size=$(du -h "$MYSQL_BACKUP" | cut -f1)
    local lines=$(wc -l < "$MYSQL_BACKUP")
    
    success "MySQL backup verified"
    log "  - File: $MYSQL_BACKUP"
    log "  - Size: $size"
    log "  - Lines: $lines"
    
    return 0
}

# Verify MongoDB backup
verify_mongodb() {
    log "Verifying MongoDB backup..."
    
    if [ ! -d "$MONGO_BACKUP_DIR" ]; then
        error "MongoDB backup directory not found: $MONGO_BACKUP_DIR"
        return 1
    fi
    
    if [ -z "$(ls -A $MONGO_BACKUP_DIR)" ]; then
        error "MongoDB backup directory is empty"
        return 1
    fi
    
    # Check for BSON files
    local bson_count=$(find "$MONGO_BACKUP_DIR" -name "*.bson" | wc -l)
    if [ "$bson_count" -eq 0 ]; then
        error "No BSON files found in MongoDB backup"
        return 1
    fi
    
    local size=$(du -sh "$MONGO_BACKUP_DIR" | cut -f1)
    
    success "MongoDB backup verified"
    log "  - Directory: $MONGO_BACKUP_DIR"
    log "  - Size: $size"
    log "  - BSON files: $bson_count"
    
    return 0
}

# Verify media backup
verify_media() {
    log "Verifying media backup..."
    
    if [ ! -d "$MEDIA_BACKUP_DIR" ]; then
        error "Media backup directory not found: $MEDIA_BACKUP_DIR"
        return 1
    fi
    
    local size=$(du -sh "$MEDIA_BACKUP_DIR" | cut -f1)
    local file_count=$(find "$MEDIA_BACKUP_DIR" -type f | wc -l)
    
    success "Media backup verified"
    log "  - Directory: $MEDIA_BACKUP_DIR"
    log "  - Size: $size"
    log "  - Files: $file_count"
    
    return 0
}

# Verify application data backup
verify_data() {
    log "Verifying application data backup..."
    
    if [ ! -d "$DATA_BACKUP_DIR" ]; then
        error "Data backup directory not found: $DATA_BACKUP_DIR"
        return 1
    fi
    
    local size=$(du -sh "$DATA_BACKUP_DIR" | cut -f1)
    local file_count=$(find "$DATA_BACKUP_DIR" -type f | wc -l)
    
    success "Application data backup verified"
    log "  - Directory: $DATA_BACKUP_DIR"
    log "  - Size: $size"
    log "  - Files: $file_count"
    
    return 0
}

# Generate verification report
generate_report() {
    local report_file="backup-verification-$(date +%Y%m%d-%H%M%S).txt"
    
    log "Generating verification report: $report_file"
    
    {
        echo "Backup Verification Report"
        echo "=========================="
        echo "Date: $(date)"
        echo ""
        echo "MySQL Backup:"
        echo "  - File: $MYSQL_BACKUP"
        echo "  - Size: $(du -h "$MYSQL_BACKUP" 2>/dev/null | cut -f1 || echo 'N/A')"
        echo "  - Lines: $(wc -l < "$MYSQL_BACKUP" 2>/dev/null || echo 'N/A')"
        echo ""
        echo "MongoDB Backup:"
        echo "  - Directory: $MONGO_BACKUP_DIR"
        echo "  - Size: $(du -sh "$MONGO_BACKUP_DIR" 2>/dev/null | cut -f1 || echo 'N/A')"
        echo "  - BSON files: $(find "$MONGO_BACKUP_DIR" -name "*.bson" 2>/dev/null | wc -l || echo 'N/A')"
        echo ""
        echo "Media Backup:"
        echo "  - Directory: $MEDIA_BACKUP_DIR"
        echo "  - Size: $(du -sh "$MEDIA_BACKUP_DIR" 2>/dev/null | cut -f1 || echo 'N/A')"
        echo "  - Files: $(find "$MEDIA_BACKUP_DIR" -type f 2>/dev/null | wc -l || echo 'N/A')"
        echo ""
        echo "Application Data Backup:"
        echo "  - Directory: $DATA_BACKUP_DIR"
        echo "  - Size: $(du -sh "$DATA_BACKUP_DIR" 2>/dev/null | cut -f1 || echo 'N/A')"
        echo "  - Files: $(find "$DATA_BACKUP_DIR" -type f 2>/dev/null | wc -l || echo 'N/A')"
    } > "$report_file"
    
    success "Report generated: $report_file"
}

# Main execution
main() {
    log "Starting backup verification..."
    
    local failed=0
    
    verify_mysql || failed=$((failed + 1))
    verify_mongodb || failed=$((failed + 1))
    verify_media || failed=$((failed + 1))
    verify_data || failed=$((failed + 1))
    
    generate_report
    
    if [ $failed -eq 0 ]; then
        success "All backups verified successfully!"
        return 0
    else
        error "$failed backup(s) failed verification"
        return 1
    fi
}

# Run main function
main "$@"
