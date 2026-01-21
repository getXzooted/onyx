function apply_vpn_transport() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing VPN Transport to $ONYX_VPN_ENDPOINT..."
        # Utilizes the agnostic build_rule for idempotency
        build_rule OUTPUT -d "$ONYX_VPN_ENDPOINT" -p udp --dport "$ONYX_VPN_PORT" -j ACCEPT
    else
        log_warning "Reverting VPN Transport Exception..."
        # Specifically removes the transport exception
        delete_rule OUTPUT -d "$ONYX_VPN_ENDPOINT" -p udp --dport "$ONYX_VPN_PORT" -j ACCEPT
    fi
}

function check_vpn_transport() {
    local INTENT=$1

    # Verify if the tunnel's physical exit point is permitted in the live firewall
    iptables -C OUTPUT -d "$ONYX_VPN_ENDPOINT" -p udp --dport "$ONYX_VPN_PORT" -j ACCEPT &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # Match intent 'true' with rule present (STATUS 0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    # Match intent 'false' with rule missing (STATUS non-zero)
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted from YAML intent
    return 1
}