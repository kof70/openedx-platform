#!/bin/bash
# Health Check Script
# Validates all services are healthy and accessible

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LMS_URL="${LMS_URL:-http://localhost}"
CMS_URL="${CMS_URL:-http://localhost:8001}"
TIMEOUT="${TIMEOUT:-10}"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if service is running
check_service() {
    local service_name="$1"
    
    if docker-compose ps | grep "$service_name" | grep -q "Up"; then
        success "$service_name is running"
        return 0
    else
        error "$service_name is not running"
        return 1
    fi
}

# Check MySQL connectivity
check_mysql() {
    log "Checking MySQL..."
    
    if docker-compose exec -T mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
        success "MySQL is healthy"
        return 0
    else
        error "MySQL is not responding"
        return 1
    fi
}

# Check MongoDB connectivity
check_mongodb() {
    log "Checking MongoDB..."
    
    if docker-compose exec -T mongodb mongosh --quiet --eval "db.adminCommand('ping').ok" 2>/dev/null | grep -q "1"; then
        success "MongoDB is healthy"
        return 0
    else
        error "MongoDB is not responding"
        return 1
    fi
}

# Check Redis connectivity
check_redis() {
    log "Checking Redis..."
    
    if docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        success "Redis is healthy"
        return 0
    else
        error "Redis is not responding"
        return 1
    fi
}

# Check Meilisearch connectivity
check_meilisearch() {
    log "Checking Meilisearch..."
    
    if curl -f -s --max-time "$TIMEOUT" http://localhost:7700/health > /dev/null 2>&1; then
        success "Meilisearch is healthy"
        return 0
    else
        error "Meilisearch is not responding"
        return 1
    fi
}

# Check LMS health
check_lms() {
    log "Checking LMS..."
    
    if curl -f -s --max-time "$TIMEOUT" "$LMS_URL/health" > /dev/null 2>&1; then
        success "LMS is healthy"
        return 0
    else
        error "LMS is not responding"
        return 1
    fi
}

# Check CMS health
check_cms() {
    log "Checking CMS..."
    
    if curl -f -s --max-time "$TIMEOUT" "$CMS_URL/health" > /dev/null 2>&1; then
        success "CMS is healthy"
        return 0
    else
        error "CMS is not responding"
        return 1
    fi
}

# Check Caddy
check_caddy() {
    log "Checking Caddy..."
    
    if docker-compose ps | grep "caddy" | grep -q "Up"; then
        success "Caddy is running"
        return 0
    else
        error "Caddy is not running"
        return 1
    fi
}

# Check Celery workers
check_workers() {
    log "Checking Celery workers..."
    
    local lms_worker_ok=0
    local cms_worker_ok=0
    
    if docker-compose ps | grep "lms-worker" | grep -q "Up"; then
        success "LMS worker is running"
        lms_worker_ok=1
    else
        error "LMS worker is not running"
    fi
    
    if docker-compose ps | grep "cms-worker" | grep -q "Up"; then
        success "CMS worker is running"
        cms_worker_ok=1
    else
        error "CMS worker is not running"
    fi
    
    if [ $lms_worker_ok -eq 1 ] && [ $cms_worker_ok -eq 1 ]; then
        return 0
    else
        return 1
    fi
}

# Check service logs for errors
check_logs() {
    log "Checking recent logs for errors..."
    
    local error_count=$(docker-compose logs --tail=100 2>&1 | grep -i "error" | wc -l)
    
    if [ "$error_count" -gt 0 ]; then
        warning "Found $error_count error messages in recent logs"
        warning "Run 'docker-compose logs' to investigate"
    else
        success "No errors found in recent logs"
    fi
}

# Generate health report
generate_report() {
    local report_file="health-check-$(date +%Y%m%d-%H%M%S).txt"
    
    log "Generating health report: $report_file"
    
    {
        echo "Health Check Report"
        echo "==================="
        echo "Date: $(date)"
        echo ""
        echo "Services Status:"
        docker-compose ps
        echo ""
        echo "Container Resource Usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    } > "$report_file"
    
    success "Report generated: $report_file"
}

# Main execution
main() {
    log "Starting health check..."
    
    local failed=0
    
    # Check infrastructure services
    check_mysql || failed=$((failed + 1))
    check_mongodb || failed=$((failed + 1))
    check_redis || failed=$((failed + 1))
    check_meilisearch || failed=$((failed + 1))
    
    # Check application services
    check_lms || failed=$((failed + 1))
    check_cms || failed=$((failed + 1))
    check_caddy || failed=$((failed + 1))
    check_workers || failed=$((failed + 1))
    
    # Check logs
    check_logs
    
    # Generate report
    generate_report
    
    echo ""
    if [ $failed -eq 0 ]; then
        success "All health checks passed!"
        return 0
    else
        error "$failed health check(s) failed"
        return 1
    fi
}

# Run main function
main "$@"
