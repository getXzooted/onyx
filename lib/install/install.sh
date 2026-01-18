#!/bin/bash
# CORE: ONYX INSTALL COMMAND
# Purpose: Handles the installation of ONYX modules

function onyx_install() {
    # Check if the installation script exists
    local INSTALL_SCRIPT="$LIB_DIR/install/install.sh"

    if [ -f "$INSTALL_SCRIPT" ]; then
        log_header "--- STARTING INSTALLATION ---"
        source "$INSTALL_SCRIPT"
    else
        log_error "Install module not found at $INSTALL_SCRIPT"
        log_info "Please ensure lib/install/install.sh exists."
        exit 1
    fi
}