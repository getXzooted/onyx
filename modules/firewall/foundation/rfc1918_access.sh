function apply_rfc1918_access() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Universal Local Access (RFC1918)..."
        build_rule INPUT -s 10.0.0.0/8 -j ACCEPT
        build_rule OUTPUT -d 10.0.0.0/8 -j ACCEPT
        build_rule INPUT -s 172.16.0.0/12 -j ACCEPT
        build_rule OUTPUT -d 172.16.0.0/12 -j ACCEPT
        build_rule INPUT -s 192.168.0.0/16 -j ACCEPT
        build_rule OUTPUT -d 192.168.0.0/16 -j ACCEPT
    else
        log_warning "Reverting Universal Local Access (RFC1918)..."
        delete_rule INPUT -s 10.0.0.0/8 -j ACCEPT
        delete_rule OUTPUT -d 10.0.0.0/8 -j ACCEPT
        delete_rule INPUT -s 172.16.0.0/12 -j ACCEPT
        delete_rule OUTPUT -d 172.16.0.0/12 -j ACCEPT
        delete_rule INPUT -s 192.168.0.0/16 -j ACCEPT
        delete_rule OUTPUT -d 192.168.0.0/16 -j ACCEPT
    fi
}

function check_rfc1918_access() {
    local INTENT=$1

    # Verify if all internal subnet ranges are physically permitted in the firewall
    iptables -C INPUT -s 10.0.0.0/8 -j ACCEPT &>/dev/null && \
    iptables -C INPUT -s 172.16.0.0/12 -j ACCEPT &>/dev/null && \
    iptables -C INPUT -s 192.168.0.0/16 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -d 10.0.0.0/8 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -d 172.16.0.0/12 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -d 192.168.0.0/16 -j ACCEPT &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and ALL rules are present (STATUS 0) -> Sync (0)
    # 2. Intent is 'false' and rules are missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, the live system state has drifted from the YAML intent
    return 1
}