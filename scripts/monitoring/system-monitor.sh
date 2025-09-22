#!/bin/bash

# IPFS Building Materials System Monitor
# Monitors system health, performance, and storage usage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_DIR="monitoring"
LOG_DIR="${MONITOR_DIR}/logs"
ALERT_DIR="${MONITOR_DIR}/alerts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create monitoring directories
mkdir -p "$MONITOR_DIR" "$LOG_DIR" "$ALERT_DIR"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_DIR/monitor.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_DIR/monitor.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/monitor.log"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_DIR/monitor.log"
}

# Check if IPFS daemon is running
check_daemon_status() {
    log_info "Checking IPFS daemon status..."
    
    if pgrep -f "ipfs daemon" > /dev/null; then
        log_info "✓ IPFS daemon is running"
        echo "running" > "$MONITOR_DIR/daemon-status.txt"
        return 0
    else
        log_error "✗ IPFS daemon is not running"
        echo "stopped" > "$MONITOR_DIR/daemon-status.txt"
        return 1
    fi
}

# Get basic node information
get_node_info() {
    log_info "Gathering node information..."
    
    if ! check_daemon_status; then
        log_error "Cannot get node info - daemon not running"
        return 1
    fi
    
    local node_id
    local addresses
    local version
    
    node_id=$(ipfs id --format="<id>" 2>/dev/null || echo "unknown")
    version=$(ipfs version --number 2>/dev/null || echo "unknown")
    
    cat > "$MONITOR_DIR/node-info.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "node_id": "$node_id",
    "version": "$version",
    "status": "$(cat $MONITOR_DIR/daemon-status.txt)"
}
EOF

    log_info "Node ID: $node_id"
    log_info "Version: $version"
}

# Check peer connections
check_peer_connections() {
    log_info "Checking peer connections..."
    
    if ! check_daemon_status; then
        log_error "Cannot check peers - daemon not running"
        return 1
    fi
    
    local peer_count
    local peers_file="$MONITOR_DIR/peers.txt"
    
    ipfs swarm peers > "$peers_file" 2>/dev/null || true
    peer_count=$(wc -l < "$peers_file")
    
    log_info "Connected peers: $peer_count"
    
    # Alert if peer count is too low
    if [ "$peer_count" -lt 5 ]; then
        log_warn "Low peer count detected: $peer_count"
        echo "$(date -Iseconds): Low peer count: $peer_count" >> "$ALERT_DIR/connectivity.log"
    fi
    
    echo "$peer_count" > "$MONITOR_DIR/peer-count.txt"
    return 0
}

# Check repository status and storage
check_storage() {
    log_info "Checking storage status..."
    
    if ! check_daemon_status; then
        log_error "Cannot check storage - daemon not running"
        return 1
    fi
    
    local repo_stats_file="$MONITOR_DIR/repo-stats.txt"
    local storage_file="$MONITOR_DIR/storage-info.json"
    
    # Get repository statistics
    ipfs repo stat > "$repo_stats_file" 2>/dev/null || {
        log_error "Failed to get repository statistics"
        return 1
    }
    
    # Parse storage information
    local repo_size
    local num_objects
    local storage_max
    
    repo_size=$(grep "RepoSize" "$repo_stats_file" | awk '{print $2}' || echo "0")
    num_objects=$(grep "NumObjects" "$repo_stats_file" | awk '{print $2}' || echo "0")
    storage_max=$(ipfs config Datastore.StorageMax 2>/dev/null || echo "unknown")
    
    # Calculate storage percentage if possible
    local storage_percent="unknown"
    if [ "$storage_max" != "unknown" ] && [ "$repo_size" != "0" ]; then
        # Convert storage_max to bytes if it has a unit
        local max_bytes
        case "$storage_max" in
            *GB) max_bytes=$(echo "${storage_max%GB} * 1024 * 1024 * 1024" | bc -l) ;;
            *MB) max_bytes=$(echo "${storage_max%MB} * 1024 * 1024" | bc -l) ;;
            *KB) max_bytes=$(echo "${storage_max%KB} * 1024" | bc -l) ;;
            *) max_bytes="$storage_max" ;;
        esac
        
        if [ "$max_bytes" != "unknown" ] && command -v bc > /dev/null; then
            storage_percent=$(echo "scale=2; $repo_size * 100 / $max_bytes" | bc -l)
        fi
    fi
    
    # Create storage report
    cat > "$storage_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "repository_size_bytes": $repo_size,
    "number_of_objects": $num_objects,
    "storage_limit": "$storage_max",
    "storage_usage_percent": "$storage_percent"
}
EOF

    log_info "Repository size: $repo_size bytes"
    log_info "Number of objects: $num_objects"
    log_info "Storage limit: $storage_max"
    
    # Alert if storage is getting full
    if [ "$storage_percent" != "unknown" ] && command -v bc > /dev/null; then
        if (( $(echo "$storage_percent > 80" | bc -l) )); then
            log_warn "Storage usage is high: ${storage_percent}%"
            echo "$(date -Iseconds): High storage usage: ${storage_percent}%" >> "$ALERT_DIR/storage.log"
        fi
    fi
}

# Check pinned content
check_pinned_content() {
    log_info "Checking pinned content..."
    
    if ! check_daemon_status; then
        log_error "Cannot check pinned content - daemon not running"
        return 1
    fi
    
    local pins_file="$MONITOR_DIR/pinned-content.txt"
    local pins_summary="$MONITOR_DIR/pins-summary.json"
    
    # List all pins
    ipfs pin ls --type recursive > "$pins_file" 2>/dev/null || {
        log_error "Failed to list pinned content"
        return 1
    }
    
    local pin_count
    pin_count=$(wc -l < "$pins_file")
    
    log_info "Pinned objects: $pin_count"
    
    # Create pins summary
    cat > "$pins_summary" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_pins": $pin_count,
    "pin_types": {
        "recursive": $pin_count
    }
}
EOF

    echo "$pin_count" > "$MONITOR_DIR/pin-count.txt"
}

# Performance test
run_performance_test() {
    log_info "Running performance test..."
    
    if ! check_daemon_status; then
        log_error "Cannot run performance test - daemon not running"
        return 1
    fi
    
    local test_file="/tmp/ipfs-test-$(date +%s).txt"
    local perf_file="$MONITOR_DIR/performance.json"
    
    # Create test content
    echo "IPFS Performance Test - $(date)" > "$test_file"
    
    # Test content addition
    local start_time
    local end_time
    local add_time
    local hash
    
    start_time=$(date +%s%N)
    hash=$(ipfs add -q "$test_file" 2>/dev/null || echo "failed")
    end_time=$(date +%s%N)
    
    if [ "$hash" = "failed" ]; then
        log_error "Performance test failed - could not add content"
        rm -f "$test_file"
        return 1
    fi
    
    add_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    # Test content retrieval
    local retrieve_start
    local retrieve_end
    local retrieve_time
    local retrieve_file="/tmp/ipfs-retrieve-$(date +%s).txt"
    
    retrieve_start=$(date +%s%N)
    ipfs cat "$hash" > "$retrieve_file" 2>/dev/null
    retrieve_end=$(date +%s%N)
    
    retrieve_time=$(( (retrieve_end - retrieve_start) / 1000000 )) # Convert to milliseconds
    
    # Verify content integrity
    local integrity_status="passed"
    if ! diff "$test_file" "$retrieve_file" > /dev/null 2>&1; then
        integrity_status="failed"
        log_error "Content integrity check failed!"
    fi
    
    # Create performance report
    cat > "$perf_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "add_time_ms": $add_time,
    "retrieve_time_ms": $retrieve_time,
    "test_hash": "$hash",
    "integrity_check": "$integrity_status"
}
EOF

    log_info "Add time: ${add_time}ms"
    log_info "Retrieve time: ${retrieve_time}ms"
    log_info "Integrity check: $integrity_status"
    
    # Cleanup
    rm -f "$test_file" "$retrieve_file"
    
    # Alert on poor performance
    if [ "$add_time" -gt 5000 ] || [ "$retrieve_time" -gt 5000 ]; then
        log_warn "Poor performance detected - add: ${add_time}ms, retrieve: ${retrieve_time}ms"
        echo "$(date -Iseconds): Poor performance - add: ${add_time}ms, retrieve: ${retrieve_time}ms" >> "$ALERT_DIR/performance.log"
    fi
}

# Check system resources
check_system_resources() {
    log_info "Checking system resources..."
    
    local resources_file="$MONITOR_DIR/system-resources.json"
    
    # Get system information
    local cpu_usage
    local memory_usage
    local disk_usage
    local load_average
    
    # CPU usage (if available)
    if command -v top > /dev/null; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "unknown")
    else
        cpu_usage="unknown"
    fi
    
    # Memory usage
    if command -v free > /dev/null; then
        memory_usage=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}' || echo "unknown")
    else
        memory_usage="unknown"
    fi
    
    # Disk usage of current directory
    if command -v df > /dev/null; then
        disk_usage=$(df -h . | awk 'NR==2{print $5}' | sed 's/%//' || echo "unknown")
    else
        disk_usage="unknown"
    fi
    
    # Load average
    if [ -f /proc/loadavg ]; then
        load_average=$(cat /proc/loadavg | awk '{print $1}' || echo "unknown")
    else
        load_average="unknown"
    fi
    
    # Create resources report
    cat > "$resources_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "cpu_usage_percent": "$cpu_usage",
    "memory_usage_percent": "$memory_usage",
    "disk_usage_percent": "$disk_usage",
    "load_average": "$load_average"
}
EOF

    log_info "CPU usage: ${cpu_usage}%"
    log_info "Memory usage: ${memory_usage}%"
    log_info "Disk usage: ${disk_usage}%"
    log_info "Load average: $load_average"
}

# Generate health report
generate_health_report() {
    log_info "Generating health report..."
    
    local health_file="$MONITOR_DIR/health-report.json"
    local timestamp
    timestamp=$(date -Iseconds)
    
    # Collect all status information
    local daemon_status
    local peer_count
    local pin_count
    
    daemon_status=$(cat "$MONITOR_DIR/daemon-status.txt" 2>/dev/null || echo "unknown")
    peer_count=$(cat "$MONITOR_DIR/peer-count.txt" 2>/dev/null || echo "0")
    pin_count=$(cat "$MONITOR_DIR/pin-count.txt" 2>/dev/null || echo "0")
    
    # Determine overall health status
    local health_status="healthy"
    local issues=()
    
    if [ "$daemon_status" != "running" ]; then
        health_status="critical"
        issues+=("daemon_not_running")
    fi
    
    if [ "$peer_count" -lt 5 ]; then
        health_status="warning"
        issues+=("low_peer_count")
    fi
    
    # Create health report
    cat > "$health_file" << EOF
{
    "timestamp": "$timestamp",
    "overall_status": "$health_status",
    "daemon_status": "$daemon_status",
    "peer_count": $peer_count,
    "pinned_objects": $pin_count,
    "issues": [$(printf '"%s",' "${issues[@]}" | sed 's/,$//')],
    "last_check": "$timestamp"
}
EOF

    log_info "Overall health status: $health_status"
    
    # Upload health report to IPFS if daemon is running
    if [ "$daemon_status" = "running" ]; then
        local health_hash
        health_hash=$(ipfs add -q "$health_file" 2>/dev/null || echo "failed")
        if [ "$health_hash" != "failed" ]; then
            log_info "Health report uploaded to IPFS: $health_hash"
            echo "$health_hash" > "$MONITOR_DIR/health-report-hash.txt"
        fi
    fi
}

# Main monitoring function
run_monitoring() {
    log_info "Starting IPFS Building Materials System monitoring..."
    log_info "Timestamp: $(date)"
    
    get_node_info
    check_peer_connections
    check_storage
    check_pinned_content
    run_performance_test
    check_system_resources
    generate_health_report
    
    log_info "Monitoring completed"
}

# Display current status
show_status() {
    echo "=== IPFS Building Materials System Status ==="
    echo "Timestamp: $(date)"
    echo
    
    if [ -f "$MONITOR_DIR/health-report.json" ]; then
        local status
        status=$(jq -r '.overall_status' "$MONITOR_DIR/health-report.json" 2>/dev/null || echo "unknown")
        
        case "$status" in
            "healthy") echo -e "Overall Status: ${GREEN}HEALTHY${NC}" ;;
            "warning") echo -e "Overall Status: ${YELLOW}WARNING${NC}" ;;
            "critical") echo -e "Overall Status: ${RED}CRITICAL${NC}" ;;
            *) echo "Overall Status: UNKNOWN" ;;
        esac
        echo
        
        # Show key metrics
        echo "Key Metrics:"
        echo "  Daemon: $(jq -r '.daemon_status' "$MONITOR_DIR/health-report.json" 2>/dev/null || echo "unknown")"
        echo "  Peers: $(jq -r '.peer_count' "$MONITOR_DIR/health-report.json" 2>/dev/null || echo "unknown")"
        echo "  Pinned Objects: $(jq -r '.pinned_objects' "$MONITOR_DIR/health-report.json" 2>/dev/null || echo "unknown")"
        
        if [ -f "$MONITOR_DIR/performance.json" ]; then
            echo "  Last Performance Test:"
            echo "    Add Time: $(jq -r '.add_time_ms' "$MONITOR_DIR/performance.json" 2>/dev/null || echo "unknown")ms"
            echo "    Retrieve Time: $(jq -r '.retrieve_time_ms' "$MONITOR_DIR/performance.json" 2>/dev/null || echo "unknown")ms"
        fi
    else
        echo "No health report available. Run monitoring first."
    fi
}

# Handle script arguments
case "${1:-}" in
    "run")
        run_monitoring
        ;;
    "status")
        show_status
        ;;
    "daemon")
        check_daemon_status
        ;;
    "peers")
        check_peer_connections
        ;;
    "storage")
        check_storage
        ;;
    "performance")
        run_performance_test
        ;;
    *)
        echo "Usage: $0 {run|status|daemon|peers|storage|performance}"
        echo "  run         - Run complete monitoring check"
        echo "  status      - Show current system status"
        echo "  daemon      - Check daemon status only"
        echo "  peers       - Check peer connections only"
        echo "  storage     - Check storage status only"
        echo "  performance - Run performance test only"
        exit 1
        ;;
esac