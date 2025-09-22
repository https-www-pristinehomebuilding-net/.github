#!/bin/bash

# IPFS Setup Script for Building Materials System
# This script initializes and configures an IPFS node optimized for building materials storage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IPFS_PATH="${IPFS_PATH:-/tmp/ipfs}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if IPFS is installed
check_ipfs_installation() {
    if ! command -v ipfs &> /dev/null; then
        log_error "IPFS is not installed. Installing..."
        install_ipfs
    else
        log_info "IPFS is already installed: $(ipfs version --number)"
    fi
}

# Install IPFS
install_ipfs() {
    log_info "Downloading and installing IPFS..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) IPFS_ARCH="amd64" ;;
        arm64|aarch64) IPFS_ARCH="arm64" ;;
        armv7l) IPFS_ARCH="arm" ;;
        *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Download IPFS
    IPFS_VERSION="v0.24.0"
    IPFS_PACKAGE="kubo_${IPFS_VERSION}_linux-${IPFS_ARCH}.tar.gz"
    
    wget -q "https://dist.ipfs.io/kubo/${IPFS_VERSION}/${IPFS_PACKAGE}" -O /tmp/${IPFS_PACKAGE}
    
    # Extract and install
    cd /tmp
    tar -xzf ${IPFS_PACKAGE}
    sudo install kubo/ipfs /usr/local/bin/
    
    # Cleanup
    rm -rf /tmp/${IPFS_PACKAGE} /tmp/kubo
    
    log_info "IPFS installed successfully"
}

# Initialize IPFS node
initialize_ipfs() {
    log_info "Initializing IPFS node..."
    
    # Initialize with server profile for better performance
    ipfs init --profile server
    
    log_info "IPFS node initialized"
}

# Configure IPFS for building materials storage
configure_ipfs() {
    log_info "Configuring IPFS for building materials storage..."
    
    # Storage configuration
    ipfs config Datastore.StorageMax "50GB"
    ipfs config --json Datastore.BloomFilterSize 1048576
    
    # Network configuration  
    ipfs config --json Discovery.MDNS.Enabled false
    ipfs config --json Swarm.ConnMgr.HighWater 900
    ipfs config --json Swarm.ConnMgr.LowWater 600
    
    # Gateway configuration
    ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
    ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Methods '["GET", "POST", "PUT", "DELETE"]'
    
    # Experimental features
    ipfs config --json Experimental.FilestoreEnabled true
    ipfs config --json Experimental.UrlstoreEnabled true
    ipfs config --json Experimental.GraphsyncEnabled true
    
    # Routing configuration
    ipfs config Routing.Type "dht"
    
    log_info "IPFS configuration completed"
}

# Start IPFS daemon
start_daemon() {
    log_info "Starting IPFS daemon..."
    
    # Check if daemon is already running
    if pgrep -f "ipfs daemon" > /dev/null; then
        log_warn "IPFS daemon is already running"
        return 0
    fi
    
    # Start daemon in background
    nohup ipfs daemon > /tmp/ipfs-daemon.log 2>&1 &
    
    # Wait for daemon to start
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ipfs id > /dev/null 2>&1; then
            log_info "IPFS daemon started successfully"
            return 0
        fi
        
        sleep 1
        attempt=$((attempt + 1))
    done
    
    log_error "Failed to start IPFS daemon"
    return 1
}

# Create initial directory structure
setup_directories() {
    log_info "Setting up directory structure..."
    
    # Create directories for different content types
    ipfs files mkdir -p /building-materials/cad-files
    ipfs files mkdir -p /building-materials/images
    ipfs files mkdir -p /building-materials/cmake-projects
    ipfs files mkdir -p /building-materials/golang-projects
    ipfs files mkdir -p /building-materials/pricing-data
    ipfs files mkdir -p /building-materials/supplier-data
    ipfs files mkdir -p /building-materials/catalogs
    
    log_info "Directory structure created"
}

# Generate system keys for different user groups
generate_keys() {
    log_info "Generating keys for user groups..."
    
    local groups=("site_planners" "material_managers" "order_trackers" "pricing_analysts" "admin")
    
    for group in "${groups[@]}"; do
        if ! ipfs key list | grep -q "^${group}$"; then
            ipfs key gen "${group}" > /dev/null
            log_info "Generated key for group: ${group}"
        else
            log_warn "Key already exists for group: ${group}"
        fi
    done
}

# Pin important system files
pin_system_files() {
    log_info "Pinning system configuration files..."
    
    # Pin catalog files if they exist
    local catalog_files=(
        "catalog/materials/catalog-structure.json"
        "catalog/materials/building-materials.json"
        "catalog/pricing/price-config.json"
        "catalog/suppliers/supplier-database.json"
    )
    
    for file in "${catalog_files[@]}"; do
        if [ -f "$file" ]; then
            local hash=$(ipfs add -q "$file")
            ipfs pin add "$hash"
            log_info "Pinned: $file -> $hash"
        fi
    done
}

# Display system status
show_status() {
    log_info "IPFS System Status:"
    echo "===================="
    
    # Node information
    local node_id=$(ipfs id --format="<id>")
    echo "Node ID: $node_id"
    
    # Peer count
    local peer_count=$(ipfs swarm peers | wc -l)
    echo "Connected Peers: $peer_count"
    
    # Repository stats
    echo -e "\nRepository Statistics:"
    ipfs repo stat
    
    # Pinned content
    local pinned_count=$(ipfs pin ls --type recursive | wc -l)
    echo -e "\nPinned Objects: $pinned_count"
    
    # Key list
    echo -e "\nGenerated Keys:"
    ipfs key list
}

# Main setup function
main() {
    log_info "Starting IPFS Building Materials System setup..."
    
    check_ipfs_installation
    
    if [ ! -d "$IPFS_PATH" ]; then
        initialize_ipfs
    else
        log_info "IPFS repository already exists"
    fi
    
    configure_ipfs
    start_daemon
    setup_directories
    generate_keys
    pin_system_files
    show_status
    
    log_info "IPFS Building Materials System setup completed!"
    log_info "Gateway URL: http://127.0.0.1:8080"
    log_info "API URL: http://127.0.0.1:5001"
}

# Handle script arguments
case "${1:-}" in
    "start")
        start_daemon
        ;;
    "status")
        show_status
        ;;
    "setup")
        main
        ;;
    *)
        echo "Usage: $0 {setup|start|status}"
        echo "  setup  - Complete IPFS setup for building materials system"
        echo "  start  - Start IPFS daemon"
        echo "  status - Show system status"
        exit 1
        ;;
esac