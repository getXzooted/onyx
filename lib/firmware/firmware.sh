#!/bin/bash
# CORE: ONYX FIRMWARE COMMAND
# Purpose: Handles the firmware updating of ONYX modules

function onyx_firmware() {

        # Check if the firmware script exists
        local FIRMWARE_SCRIPT="$MODULES_DIR/system/firmware.sh"

        if [ -f "$FIRMWARE_SCRIPT" ]; then
            log_header "--- UPDATING FIRMWARE ---"
            source "$FIRMWARE_SCRIPT" "${@:2}" # Pass all flags (e.g., --fresh-hard) to the script
            return 0
        else
            log_error "Firmware module not found at $FIRMWARE_SCRIPT"
            log_info "Please ensure $MODULES_DIR/system/firmware.sh exists."
            return 1
        fi

}