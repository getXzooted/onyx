#!/bin/bash
# CORE: ONYX QR SCRIPT
# Purpose: Initializes Onyx QR code generation.
function onyx_qr() {

    # Check if the QR script exists
    local QR_SCRIPT="$MODULES_DIR/system/qr.sh"

    if [ -f "$QR_SCRIPT" ]; then
        log_header " --- LOADING QR --- "
        source "$QR_SCRIPT"
        return 0
    else
        log_error "QR module not found at $QR_SCRIPT"
        log_info "Please ensure $MODULES_DIR/system/qr.sh exists."
        return 1
    fi

}