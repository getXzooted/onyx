function apply_default_deny() {
    local INTENT=$1
    
    if [[ "$INTENT" == "true" ]]; then
        log_step "Applying Global Default Deny (FORWARD DROP)..."
        # Sets the default policy for traffic PASSING THROUGH the Pi
        iptables -P FORWARD DROP
    else
        log_warning "Reverting Default Deny (FORWARD ACCEPT)..."
        # Reverts to standard Linux behavior for troubleshooting
        iptables -P FORWARD ACCEPT
    fi
}

function check_default_deny() {
    local INTENT=$1
    
    # Check if the global policy for FORWARD is currently set to DROP
    iptables -L FORWARD -n | grep -q "policy DROP"
    local STATUS=$?

    # SYNC LOGIC:
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    return 1
}