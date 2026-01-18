#!/bin/bash
# CORE: ONYX CONFIGURATION SCRIPT
# Purpose: Handles the configuration phase of ONYX.

function onyx_config() {

        # Check if the config script exists
        local CONFIG_SCRIPT="$MODULES_DIR/system/config.sh"

        if [ -f "$CONFIG_SCRIPT" ]; then
            log_header " --- CONFIGURING ONYX --- "
            source "$CONFIG_SCRIPT"
            return 0
        else
            log_error "Install module not found at $CONFIG_SCRIPT"
            log_info "Please ensure $MODULES_DIR/system/config.sh exists."
            return 1
        fi

}