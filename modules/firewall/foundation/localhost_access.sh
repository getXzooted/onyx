function apply_localhost_access() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Localhost (lo) Access..."
        build_rule INPUT -i lo -j ACCEPT
        build_rule OUTPUT -o lo -j ACCEPT
    else
        log_warning "Reverting Localhost (lo) Access..."
        delete_rule INPUT -i lo -j ACCEPT
        delete_rule OUTPUT -o lo -j ACCEPT
    fi
}

function check_localhost_access() {
    local INTENT=$1

    # Check if local loopback is physically permitted
    iptables -C INPUT -i lo -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -o lo -j ACCEPT &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # Match intent 'true' with rules present (STATUS 0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    # Match intent 'false' with rules missing (STATUS non-zero)
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state does not match YAML intent (Drift)
    return 1
}