#!/bin/bash
# CORE: ONYX STATUS COMMAND
# Purpose: Handoff control to the diagnostic engine.

function onyx_status() {

    # 1. Check if the diagnostic tool exists
    local STATUS_SCRIPT="$MODULES_DIR/system/status.sh"

    if [ -f "$STATUS_SCRIPT" ]; then
        log_header " --- ONYX STATUS SCRIPT --- "
        sudo "$STATUS_SCRIPT" # We execute it directly (instead of source) to keep its variables isolated
        return $?
    else
        log_error "Status module not found at $STATUS_SCRIPT"
        log_info "Please ensure $MODULES_DIR/system/status.sh exists and is executable."
        return 1
    fi

}