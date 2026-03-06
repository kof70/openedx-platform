#!/bin/bash
# Rollback Script
# Rolls back to Tutor setup in case of migration failure

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Confirm rollback
confirm_rollback() {
    warning "This will stop the native setup and attempt to restart Tutor."
    warning "All data in the native setup will be preserved but not used."
    
    read -p "Are you sure you want to rollback? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Rollback cancelled"
        exit 0
    fi
}

# Stop native setup
stop_native() {
    log "Stopping native Docker Compose setup..."
    
    if docker-compose ps | grep -q "Up"; then
        docker-compose down
        success "Native setup stopped"
    else
        log "Native setup is not running"
    fi
}

# Restart Tutor
restart_tutor() {
    log "Attempting to restart Tutor..."
    
    warning "Please run the following command manually:"
    warning "  tutor local start"
    
    log "After Tutor starts, verify services are running:"
    log "  tutor local status"
}

# Verify Tutor status
verify_tutor() {
    log "Verifying Tutor status..."
    
    warning "Please verify manually that Tutor services are running:"
    warning "  1. Check LMS: https://lms.coolify.alonu.shop"
    warning "  2. Check CMS: https://studio.coolify.alonu.shop"
    warning "  3. Verify user login works"
    warning "  4. Verify course access works"
}

# Main execution
main() {
    log "Starting rollback procedure..."
    
    confirm_rollback
    stop_native
    restart_tutor
    verify_tutor
    
    success "Rollback procedure completed"
    warning "Please verify Tutor services manually"
}

# Run main function
main "$@"
