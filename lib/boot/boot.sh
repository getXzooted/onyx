#!/bin/bash
# CORE: ONYX BOOT SCRIPT
# Purpose: Initializes Onyx during system boot.

function onyx_boot() {
    
    # Check if the boot script exists
    local BOOT_SCRIPT="$MODULES_DIR/system/boot.sh"

    if [ -f "$BOOT_SCRIPT" ]; then
        log_header "--- BOOTSTRAPPING ONYX ---"
        source "$BOOT_SCRIPT"
        return 0
    else
        log_error "Boot module not found at $BOOT_SCRIPT"
        log_info "Please ensure $MODULES_DIR/system/boot.sh exists."
        return 1
    fi

}