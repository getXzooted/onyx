#!/bin/bash
# CORE: ONYX NETWORK COMMAND
# Purpose: Handles network-related operations for ONYX.

function onyx_network() {

        # Check if the network script exists
        local NETWORK_SCRIPT="$MODULES_DIR/system/network.sh"

        if [ -f "$NETWORK_SCRIPT" ]; then
            log_header "--- CONFIGURING NETWORK ---"
            source "$NETWORK_SCRIPT"
            return 0
        else
            log_error "Network module not found at $NETWORK_SCRIPT"
            log_info "Please ensure $MODULES_DIR/system/network.sh exists."
            return 1
        fi

}