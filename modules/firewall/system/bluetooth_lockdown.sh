function apply_bluetooth_lockdown() {
    local INTENT=$1
    local CONFIG="/boot/firmware/config.txt"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Bluetooth Lockdown (Service & Firmware)..."
        
        # 1. Kill the active service
        systemctl disable --now bluetooth &>/dev/null
        systemctl mask bluetooth &>/dev/null
        
        # 2. Apply Firmware Overlay (Physical Disable)
        if ! grep -q "# ONYX_BT_LOCKDOWN" "$CONFIG"; then
            cat <<EOF >> "$CONFIG"

# ONYX_BT_LOCKDOWN
dtoverlay=disable-bt
# ONYX_BT_END
EOF
            log_success "Bluetooth hardware disabled in firmware. Reboot required."
        fi
    else
        log_warning "Reverting Bluetooth Lockdown..."
        
        # 1. Restore service capability
        systemctl unmask bluetooth &>/dev/null
        systemctl enable bluetooth &>/dev/null
        
        # 2. Remove Firmware Overlay
        sed -i '/# ONYX_BT_LOCKDOWN/,/# ONYX_BT_END/d' "$CONFIG"
        log_info "Bluetooth restored. Reboot required for physical reactivation."
    fi
}

function check_bluetooth_lockdown() {
    local INTENT=$1
    local CONFIG="/boot/firmware/config.txt"

    # Check both the service state and the firmware configuration
    local SERVICE_ACTIVE=$(systemctl is-active bluetooth &>/dev/null && echo 0 || echo 1)
    local FW_DISABLED=$(grep -q "# ONYX_BT_LOCKDOWN" "$CONFIG" && echo 1 || echo 0)

    # SYNC LOGIC:
    # 1. Intent is 'true': Service must be inactive (1) AND FW must be disabled (1)
    if [[ "$INTENT" == "true" ]]; then
        [[ $SERVICE_ACTIVE -eq 1 && $FW_DISABLED -eq 1 ]] && return 0 || return 1
    fi

    # 2. Intent is 'false': Service should be active (0) AND FW should be enabled (0)
    if [[ "$INTENT" == "false" ]]; then
        [[ $SERVICE_ACTIVE -eq 0 && $FW_DISABLED -eq 0 ]] && return 0 || return 1
    fi

    return 1
}