#!/bin/bash
# CORE: ONYX SSH SCRIPT
# Purpose: Initializes Onyx SSH access.

function onyx_ssh() {

    # Check if the SSH script exists
    local SSH_SCRIPT="$MODULES_DIR/system/ssh.sh"

    if [ -f "$SSH_SCRIPT" ]; then
        log_header " --- LOADING SSH --- "
        source "$SSH_SCRIPT"
        return 0
    else
        log_error "SSH module not found at $SSH_SCRIPT"
        log_info "Please ensure $MODULES_DIR/system/ssh.sh exists."
        return 1
    fi

}