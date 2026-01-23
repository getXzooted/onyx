function apply_honeypot_trap() {
    local INTENT=$1
    local PORTS="23,3389"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Honeypot Trap (Ports: $PORTS)..."
        
        # 1. Check for the preferred module
        if modprobe xt_TARPIT 2>/dev/null; then
            log_info "TARPIT module active. Engaging resource-drain trap."
            build_rule INPUT -p tcp -m multiport --dports "$PORTS" -j TARPIT \
                -m comment --comment "ONYX_HONEYPOT_TARPIT"
            # Cleanup legacy fallback if it exists
            delete_rule INPUT -p tcp -m multiport --dports "$PORTS" -j REJECT --reject-with tcp-reset \
                -m comment --comment "ONYX_HONEYPOT_RESET"
        else
            log_warning "TARPIT module missing. Falling back to TCP-Reset."
            build_rule INPUT -p tcp -m multiport --dports "$PORTS" -j REJECT --reject-with tcp-reset \
                -m comment --comment "ONYX_HONEYPOT_RESET"
        fi
    else
        log_warning "Deactivating Honeypot Trap..."
        # Surgical cleanup of all possible trap implementations
        delete_rule INPUT -p tcp -m multiport --dports "$PORTS" -j TARPIT \
            -m comment --comment "ONYX_HONEYPOT_TARPIT"
        delete_rule INPUT -p tcp -m multiport --dports "$PORTS" -j REJECT --reject-with tcp-reset \
            -m comment --comment "ONYX_HONEYPOT_RESET"
    fi
}

function check_honeypot_trap() {
    local INTENT=$1
    
    # Check for either specific Onyx implementation label
    iptables -S INPUT 2>/dev/null | grep -qE "ONYX_HONEYPOT_TARPIT|ONYX_HONEYPOT_RESET"
    local RULE_EXISTS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and a rule exists -> Sync (0)
    if [[ "$INTENT" == "true" && $RULE_EXISTS -eq 0 ]]; then
        # Extra Credit: If we have a RESET rule but TARPIT is now available, it's a drift (upgrade)
        if iptables -S INPUT 2>/dev/null | grep -q "ONYX_HONEYPOT_RESET" && modinfo xt_TARPIT &>/dev/null; then
            log_info "Upgrade available: Honeypot can now use TARPIT."
            return 1
        fi
        return 0
    fi

    # 2. Intent is 'false' and rules are gone -> Sync (0)
    if [[ "$INTENT" == "false" && $RULE_EXISTS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted
    return 1
}