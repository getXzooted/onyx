#!/bin/bash
# CORE: ONYX BOOTSTRAP SCRIPT
# Purpose: Initializes the Onyx Gateway during system boot.

function onyx_boot() {
    # Check if the boot script exists
    BOOT_SCRIPT="$MODULES_DIR/system/boot.sh"

    if [ -f "$BOOT_SCRIPT" ]; then
        log_header "--- BOOTSTRAPPING ONYX GATEWAY ---"
        source "$BOOT_SCRIPT"
    else
        log_error "Boot module not found at $BOOT_SCRIPT"
        log_info "Please ensure $MODULES_DIR/system/boot.sh exists."
        return 1
    fi

    return 0
}