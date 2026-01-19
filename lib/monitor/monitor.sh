#!/bin/bash
# CORE: ONYX MONITOR SCRIPT
# Purpose: Initializes Onyx monitoring.

function onyx_monitor() {

    # Check if the monitor script exists
    local MONITOR_SCRIPT="/usr/local/bin/onyx-dash"

    if [ -f "$MONITOR_SCRIPT" ]; then
        log_header " --- ONYX MONITOR --- "
        /usr/local/bin/onyx-dash
        return 0
    else
        log_error "Monitor module not found at $MONITOR_SCRIPT"
        log_info "Please run 'sudo onyx dashboard' to install the Onyx dashboard for monitoring."
        return 1
    fi

}