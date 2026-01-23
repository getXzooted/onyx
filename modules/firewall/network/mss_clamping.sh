function apply_mss_clamping() {
    local INTENT=$1
    # Agnostic: Use configured VPN interface or default to wg0
    local IFACE="${ONYX_VPN_IFACE:-wg0}"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing MSS Clamping ($IFACE)..."
        # Only apply if not already present (Idempotency)
        if ! iptables -t mangle -C POSTROUTING -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu &>/dev/null; then
            iptables -t mangle -A POSTROUTING -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        fi
    else
        log_warning "Reverting MSS Clamping ($IFACE)..."
        # Surgical removal from the mangle table
        iptables -t mangle -D POSTROUTING -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null
    fi
}

function check_mss_clamping() {
    local INTENT=$1
    local IFACE="${ONYX_VPN_IFACE:-wg0}"

    # Verify if the rule exists in the mangle table
    iptables -t mangle -C POSTROUTING -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    return 1
}