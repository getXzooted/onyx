#!/bin/bash
# CORE: ONYX SSH SERVICE SCRIPT
# Purpose: Enables or disables SSH service for remote access.

case "$2" in
    on|enable)
        systemctl enable --now ssh
        log_success "SSH Service Enabled."
        ;;
    off|disable)
        systemctl disable --now ssh
        log_warning "SSH Service Disabled. Remote access locked."
        ;;
    *)
        echo "Usage: sudo onyx ssh [on|off]"
        ;;
esac