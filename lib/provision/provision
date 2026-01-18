#!/bin/bash
# CORE: ONYX PROVISION COMMAND
# Purpose: Handles the provisioning of ONYX modules

function onyx_provision() {
    
    # Check if the provisioning script exists
    local PROVISION_SCRIPT="$MODULES_DIR/provision/provision.sh"

    if [ -f "$PROVISION_SCRIPT" ]; then
        log_header "--- PROVISIONING ONYX ---"
        source "$PROVISION_SCRIPT"
        return 0
    else
        log_error "Install module not found at $PROVISION_SCRIPT"
        log_info "Please ensure $MODULES_DIR/provision/provision.sh exists."
        return 1
    fi

}