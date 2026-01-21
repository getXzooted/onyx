function apply_tunnel_integrity() {
    local INTENT=$1
    # Agnostic: Pull the VPN interface from environment or default to wg0
    local IFACE="${ONYX_VPN_IFACE:-wg0}"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Internal Tunnel Integrity ($IFACE)..."
        
        # Filter Table Rules
        build_rule INPUT -i "$IFACE" -j ACCEPT
        build_rule OUTPUT -o "$IFACE" -j ACCEPT
        build_rule FORWARD -i "$IFACE" -j ACCEPT
        build_rule FORWARD -o "$IFACE" -j ACCEPT
        
        # NAT Masquerade (Idempotent Check)
        if ! iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE &>/dev/null; then
            iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
        fi
    else
        log_warning "Reverting Internal Tunnel Integrity ($IFACE)..."
        
        # Remove Filter Rules
        delete_rule INPUT -i "$IFACE" -j ACCEPT
        delete_rule OUTPUT -o "$IFACE" -j ACCEPT
        delete_rule FORWARD -i "$IFACE" -j ACCEPT
        delete_rule FORWARD -o "$IFACE" -j ACCEPT
        
        # Remove NAT Rule
        iptables -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null
    fi
}

function check_tunnel_integrity() {
    local INTENT=$1
    local IFACE="${ONYX_VPN_IFACE:-wg0}"

    # Verify general tunnel traffic flow and NAT presence
    iptables -C INPUT -i "$IFACE" -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -o "$IFACE" -j ACCEPT &>/dev/null && \
    iptables -C FORWARD -i "$IFACE" -j ACCEPT &>/dev/null && \
    iptables -C FORWARD -o "$IFACE" -j ACCEPT &>/dev/null && \
    iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and ALL rules are present (STATUS 0) -> Sync (0)
    # 2. Intent is 'false' and rules are missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML state
    return 1
}