function apply_tcp_tarpit() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Global TCP Tarpit (State: NEW)..."
        
        # Verify module before engaging
        if modprobe xt_TARPIT 2>/dev/null; then
            log_info "TARPIT active. Global connection shield engaged."
            build_rule INPUT -p tcp -m state --state NEW -j TARPIT \
                -m comment --comment "ONYX_TCP_TARPIT"
        else
            log_error "TARPIT Failure: Module missing (Kernel 6.12 issue)."
            log_info "Onyx will remain in standard Stealth (DROP) mode."
            return 1
        fi
    else
        log_warning "Deactivating Global TCP Tarpit..."
        delete_rule INPUT -p tcp -m state --state NEW -j TARPIT \
            -m comment --comment "ONYX_TCP_TARPIT"
    fi
}

function check_tcp_tarpit() {
    local INTENT=$1

    # Search for the specific label to distinguish from the Honeypot
    iptables -S INPUT 2>/dev/null | grep -q "ONYX_TCP_TARPIT"
    local RULE_EXISTS=$?

    # 1. Intent is 'false' (OFF)
    if [[ "$INTENT" == "false" ]]; then
        # If the rule is still there, it's a drift (1)
        [[ $RULE_EXISTS -eq 0 ]] && return 1 || return 0
    fi

    # 2. Intent is 'true' (ON)
    if [[ "$INTENT" == "true" ]]; then
        # Check for the module; if missing, we bypass to prevent repair loops
        if ! modinfo xt_TARPIT &>/dev/null; then
            log_warning "Audit Bypass: TARPIT module missing from kernel."
            return 0 
        fi

        # If module exists but rule is missing, it's a drift (1)
        [[ $RULE_EXISTS -eq 0 ]] && return 0 || return 1
    fi
}