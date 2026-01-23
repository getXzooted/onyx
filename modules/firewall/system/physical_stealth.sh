# modules/hardware/stealth_rules.sh

function apply_physical_stealth() {
    local INTENT=$1
    local CONFIG="/boot/firmware/config.txt"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Physical Stealth (Disabling Hardware LEDs)..."
        
        # Check if the block already exists to maintain idempotency
        if ! grep -q "# ONYX_STEALTH_START" "$CONFIG"; then
            cat <<EOF >> "$CONFIG"

# ONYX_STEALTH_START
dtparam=pwr_led_trigger=none
dtparam=pwr_led_activelow=off
dtparam=act_led_trigger=none
dtparam=act_led_activelow=off
# ONYX_STEALTH_END
EOF
            log_success "Firmware updated. Reboot required for physical sync."
        fi
    else
        log_warning "Reverting Physical Stealth (Restoring LEDs)..."
        # Surgically remove the block between the Onyx markers
        sed -i '/# ONYX_STEALTH_START/,/# ONYX_STEALTH_END/d' "$CONFIG"
        log_info "LED defaults restored. Reboot required for physical sync."
    fi
}

function check_physical_stealth() {
    local INTENT=$1
    local CONFIG="/boot/firmware/config.txt"

    # Search for our unique marker in the firmware config
    grep -q "# ONYX_STEALTH_START" "$CONFIG"
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and marker exists -> Sync (0)
    # 2. Intent is 'false' and marker is missing -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, firmware config has drifted
    return 1
}