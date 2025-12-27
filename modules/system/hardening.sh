#!/bin/bash
# MODULE: System Hardening
# Applies kernel-level security settings.
# Includes strict port from V1 + V2 Security Upgrades.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function system_hardening() {
    log_header "SYSTEM HARDENING"

    

    log_header "Enforcing Hardening Desired State..."
    /usr/local/bin/onyx network repair # &>/dev/null

    # Apply changes immediately
    #sysctl -p "$SYSCTL_FILE" &> /dev/null
    
    #if [ $? -eq 0 ]; then
    #    log_success "Kernel hardening applied."
    #else
    #    log_error "Failed to apply sysctl rules."
    #fi
}

system_hardening