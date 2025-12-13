#!/bin/bash
# MODULE: System Bootstrap
# Installs core dependencies and updates the OS.

# Load Logger (This assumes the script is run by the main CLI, but we add a check)
if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function system_bootstrap() {
    log_header "SYSTEM BOOTSTRAP"

    # 1. Update Repositories
    log_step "Updating package lists..."
    apt-get update -qq
    
    # 2. Install Core Dependencies
    # - wireguard: VPN protocol
    # - iptables: Firewall management
    # - unbound: Recursive DNS resolver
    # - curl/git: Utilities
    # - qrencode: For generating QR codes in terminal (cool feature for later)
    DEPENDENCIES=(wireguard iptables unbound curl git qrencode dnsmasq hostapd)
    
    log_step "Installing dependencies: ${DEPENDENCIES[*]}..."
    
    # DEBIAN_FRONTEND=noninteractive prevents popups during install
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${DEPENDENCIES[@]}"

    if [ $? -eq 0 ]; then
        log_success "All core dependencies installed."
    else
        log_error "Failed to install dependencies. Check internet connection."
        exit 1
    fi
    
    # 3. Disable unwanted services (Bluetooth) to save power/security
    log_step "Disabling Bluetooth service..."
    systemctl disable --now bluetooth &> /dev/null
    systemctl disable --now hciuart &> /dev/null
    
    # Add to boot config if not already there
    if ! grep -q "dtoverlay=disable-bt" /boot/firmware/config.txt; then
        echo "dtoverlay=disable-bt" >> /boot/firmware/config.txt
        log_success "Bluetooth disabled in boot config."
    fi
}

# Run the function
system_bootstrap