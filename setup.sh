#!/bin/bash

######################################################
# Script: setup.sh
# Purpose: Install dependencies, update system, and install nmap
# Usage: sudo ./setup.sh
######################################################

set -euo pipefail

[[ "${DEBUG:-}" == "true" ]] && set -x

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/${SCRIPT_NAME%.*}.log"

# Logging functions
log_info() { 
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_success() { 
    echo -e "${GREEN}[OK]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_warn() { 
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_error() { 
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE" >&2
}

# To check if it is running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo or as root."
        log_error "Usage: sudo $SCRIPT_NAME"
        exit 1
    fi
}

# cleanup
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Script completed successfully"
    else
        log_error "Script failed with exit code: $exit_code"
    fi
}

# signal handler
handle_interrupt() {
    log_warn "Received interrupt signal, cleaning up..."
    exit 130
}

# Check for system : debian/ubuntu based
check_system() {
    if ! command -v apt >/dev/null 2>&1; then
        log_error "This script requires a Debian/Ubuntu-based system with apt package manager"
        exit 1
    fi
    
    log_info "Detected $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
}

# Update system packages
update_system() {
    log_info "Updating package lists..."
    
    # Update with proper error handling
    if ! DEBIAN_FRONTEND=noninteractive apt update -y; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    log_info "Upgrading installed packages..."
    
    # Upgrade
    if ! DEBIAN_FRONTEND=noninteractive apt upgrade -y; then
        log_error "Failed to upgrade packages"
        return 1
    fi
    
    log_success "System update completed"
}

install_packages() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_warn "No packages specified for installation"
        return 0
    fi
    
    log_info "Processing ${#packages[@]} package(s): ${packages[*]}"
    
    for pkg in "${packages[@]}"; do
        log_info "Checking if $pkg is installed..."
        
        if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            log_info "$pkg is already installed"

            if apt list --upgradable 2>/dev/null | grep -q "^$pkg/"; then
                log_info "$pkg has updates available, upgrading..."
                DEBIAN_FRONTEND=noninteractive apt install -y "$pkg"
                log_success "$pkg upgraded successfully"
            fi
        else
            log_info "Installing $pkg..."
            
            if DEBIAN_FRONTEND=noninteractive apt install -y "$pkg"; then
                log_success "$pkg installed successfully"
            else
                log_error "Failed to install $pkg"
                return 1
            fi
        fi
    done
    
    log_success "All packages processed successfully"
}

verify_installation() {
    local packages=("$@")
    
    log_info "Verifying installation..."
    
    for pkg in "${packages[@]}"; do
        if command -v "$pkg" >/dev/null 2>&1; then
            local version
            version=$("$pkg" --version 2>/dev/null | head -n1 || echo "version unknown")
            log_success "$pkg is installed and available: $version"
        else
            log_error "$pkg command not found after installation"
            return 1
        fi
    done
}

main() {
    trap handle_interrupt SIGINT SIGTERM
    trap cleanup EXIT
    
    log_info "Starting nmap installation script..."
    
    check_root
    check_system
    
    update_system
    install_packages nmap
    verify_installation nmap
    
    log_success "All tasks completed successfully!"
    log_info "You can now use nmap. Try: nmap --help"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi