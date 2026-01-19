#!/bin/bash
# CORE: ONYX DASHBOARD SCRIPT
# Purpose: Initializes Onyx dashboard.

function onyx_dashboard() {

    # Check if the dashboard script exists
    local DASHBOARD_SCRIPT="$MODULES_DIR/system/dashboard.sh"

    if [ -f "$DASHBOARD_SCRIPT" ]; then
        log_header " --- LOADING DASHBOARD --- "
        source "$DASHBOARD_SCRIPT"
        return 0
    else
        log_error "Dashboard module not found at $DASHBOARD_SCRIPT"
        log_info "Please ensure $MODULES_DIR/system/dashboard.sh exists."
        return 1
    fi

}