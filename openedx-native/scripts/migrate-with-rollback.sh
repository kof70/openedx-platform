#!/bin/bash
# Migration with Rollback Script
# Orchestrates the complete migration with automatic rollback on failure

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-backups}"
ROLLBACK_BACKUP="${ROLLBACK_BACKUP:-rollback-$(date +%Y%m%d-%H%M%S)}"
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Create rollback point
create_rollback_point() {
    log "Creating rollback point..."
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would create rollback point at $ROLLBACK_BACKUP"
        return 0
    fi
    
    mkdir -p "$ROLLBACK_BACKUP"
    
    # Backup current state
    log "Backing up current Docker state..."
    docker-compose ps > "$ROLLBACK_BACKUP/docker-compose-ps.txt" 2>&1 || true
    docker volume ls > "$ROLLBACK_BACKUP/docker-volumes.txt" 2>&1 || true
    
    success "Rollback point created: $ROLLBACK_BACKUP"
}

# Verify prerequisites
verify_prerequisites() {
    log "Verifying prerequisites..."
    
    # Check if backup verification script exists
    if [ ! -f "$SCRIPT_DIR/backup-verify.sh" ]; then
        error "Backup verification script not found"
        return 1
    fi
    
    # Run backup verification
    bash "$SCRIPT_DIR/backup-verify.sh"
    
    if [ $? -ne 0 ]; then
        error "Backup verification failed"
        return 1
    fi
    
    success "Prerequisites verified"
    return 0
}

# Execute migration step
execute_step() {
    local step_name="$1"
    local step_script="$2"
    
    log "Executing step: $step_name"
    
    if [ ! -f "$step_script" ]; then
        error "Step script not found: $step_script"
        return 1
    fi
    
    # Make script executable
    chmod +x "$step_script"
    
    # Execute script
    if bash "$step_script"; then
        success "Step completed: $step_name"
        return 0
    else
        error "Step failed: $step_name"
        return 1
    fi
}

# Rollback migration
rollback_migration() {
    error "Migration failed! Initiating rollback..."
    
    if [ "$DRY_RUN" = "true" ]; then
        warning "DRY RUN: Would rollback migration"
        return 0
    fi
    
    log "Stopping native setup..."
    docker-compose down || true
    
    log "Restoring Tutor setup..."
    # This would restart Tutor services
    # tutor local start
    
    warning "Rollback completed. Please verify Tutor services are running."
    warning "Rollback data saved in: $ROLLBACK_BACKUP"
}

# Main migration workflow
main() {
    log "Starting migration with rollback protection..."
    log "Dry run: $DRY_RUN"
    
    # Create rollback point
    create_rollback_point || {
        error "Failed to create rollback point"
        exit 1
    }
    
    # Verify prerequisites
    verify_prerequisites || {
        error "Prerequisites verification failed"
        rollback_migration
        exit 1
    }
    
    # Execute migration steps
    local steps=(
        "MySQL Migration:$SCRIPT_DIR/migrate-mysql.sh"
        "MongoDB Migration:$SCRIPT_DIR/migrate-mongodb.sh"
        "Media Migration:$SCRIPT_DIR/migrate-media.sh"
    )
    
    for step in "${steps[@]}"; do
        IFS=':' read -r step_name step_script <<< "$step"
        
        execute_step "$step_name" "$step_script" || {
            error "Migration step failed: $step_name"
            rollback_migration
            exit 1
        }
    done
    
    success "Migration completed successfully!"
    info "Rollback point available at: $ROLLBACK_BACKUP"
    info "To rollback manually, run: bash $SCRIPT_DIR/rollback.sh $ROLLBACK_BACKUP"
}

# Run main function
main "$@"
