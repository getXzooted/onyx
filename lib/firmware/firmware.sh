#!/bin/bash
# CORE: ONYX FIRMWARE COMMAND
# Purpose: Handles the firmware updating of ONYX modules

function onyx_firmware() {

        # Check if the firmware script exists
        STATUS_SCRIPT="$ONYX_ROOT/lib/firmware/firmware.sh"

        if [ -f "$STATUS_SCRIPT" ]; then
            log_header "--- ONYX FIRMWARE UPDATE ---"
            source "$STATUS_SCRIPT" "${@:2}" # Pass all flags (e.g., --fresh-hard) to the script
            return 0
        else
            log_error "Firmware module not found at $STATUS_SCRIPT"
            log_info "Please ensure lib/firmware/firmware.sh exists."
            return 1
        fi

}