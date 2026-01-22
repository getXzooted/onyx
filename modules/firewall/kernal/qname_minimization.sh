function apply_qname_minimization() {
    local INTENT=$1
    local CONF="/etc/unbound/unbound.conf.d/pi-zero.conf"

    if [[ ! -f "$CONF" ]]; then
        log_error "Unbound configuration file not found at $CONF"
        return 1
    fi

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing QNAME Minimization (DNS Metadata Stealth)..."
        # Only inject if the line is not already present to ensure idempotency
        if ! grep -q "qname-minimisation: yes" "$CONF"; then
            sed -i '/server:/a \    qname-minimisation: yes' "$CONF"
            systemctl restart unbound &>/dev/null
            log_success "QNAME Minimization active."
        fi
    else
        log_warning "Reverting QNAME Minimization..."
        # Cleanly remove the privacy flag if present
        if grep -q "qname-minimisation: yes" "$CONF"; then
            sed -i '/qname-minimisation: yes/d' "$CONF"
            systemctl restart unbound &>/dev/null
            log_info "QNAME Minimization removed."
        fi
    fi
}

function check_qname_minimization() {
    local INTENT=$1
    local CONF="/etc/unbound/unbound.conf.d/pi-zero.conf"

    # If the config file itself is missing, the system is fundamentally drifted
    if [[ ! -f "$CONF" ]]; then return 1; fi

    # Check for the existence of the minimization flag
    grep -q "qname-minimisation: yes" "$CONF"
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and minimization is active (STATUS 0) -> Sync (0)
    # 2. Intent is 'false' and minimization is missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}