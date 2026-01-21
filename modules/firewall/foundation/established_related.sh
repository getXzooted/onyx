function apply_established_related() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Established/Related Traffic..."
        build_rule INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        build_rule OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        build_rule FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    else
        log_warning "Reverting Established/Related Rules..."
        delete_rule INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        delete_rule OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        delete_rule FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    fi
}

function check_established_related() {
    local INTENT=$1

    # Check if the rules are physically present across all chains
    iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null && \
    iptables -C FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is true and rules exist (STATUS 0) -> Sync (0)
    # 2. Intent is false and rules are missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state does not match YAML intent (Drift)
    return 1
}