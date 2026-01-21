function apply_dhcp_access() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing DHCP (67:68) Access..."
        build_rule INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
        build_rule OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
    else
        log_warning "Reverting DHCP (67:68) Access..."
        delete_rule INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
        delete_rule OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
    fi
}

function check_dhcp_access() {
    local INTENT=$1

    # Verify if DHCP rules are physically present in the firewall
    iptables -C INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # Match intent 'true' with rules present (STATUS 0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    # Match intent 'false' with rules missing (STATUS non-zero)
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state does not match YAML intent (Drift Detected)
    return 1
}