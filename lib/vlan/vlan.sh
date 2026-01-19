#!/bin/bash
# CORE: ONYX VLAN COMMAND
# Purpose: Handles VLAN-related operations for ONYX.

function onyx_vlan() {

        # Check if the VLAN script exists
        VLAN_SCRIPT="$MODULES_DIR/vlan/vlan.sh"

        if [ -f "$VLAN_SCRIPT" ]; then
            log_header " --- CONFIGURING VLAN --- "
            source "$VLAN_SCRIPT" "${@:2}"
            return $?
        else
            log_error "VLAN module not found at $VLAN_SCRIPT"
            log_info "Please ensure $MODULES_DIR/vlan/vlan.sh exists and is executable."
            return 1
        fi

}