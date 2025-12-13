#!/bin/bash
# MODULE: System > RaspAP Installer
# Installs the Hotspot Web Interface and management tools.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function system_install_raspap() {
    log_header "INSTALLING RASPAP (HOTSPOT)"

    # Check if already installed to avoid re-running the heavy installer
    if [ -d "/var/www/html/raspap" ]; then
        log_warning "RaspAP appears to be installed. Skipping."
        return 0
    fi

    log_step "Downloading and running RaspAP installer..."
    
    # We use the official installer with flags to keep it quiet and clean.
    # --yes: Accept defaults
    # --no-reboot: We manage the reboot
    # --openvpn 0: We manage VPNs ourselves
    # --wireguard 0: We manage WireGuard ourselves
    curl -sL https://install.raspap.com | bash -s -- --yes --no-reboot --openvpn 0 --wireguard 0
    
    if [ $? -eq 0 ]; then
        log_success "RaspAP installed successfully."
    else
        log_error "RaspAP installation failed."
        exit 1
    fi

    # TARGETED FIX: Ensure WiFi service is not masked
    systemctl unmask hostapd &> /dev/null
    systemctl enable hostapd &> /dev/null
}

system_install_raspap