function apply_source_port_randomization() {
    local INTENT=$1
    local VPN_PORT="${ONYX_VPN_PORT:-51820}"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Source Port Randomization (fully-random)..."
        
        # 1. Primary: Use the iptables-nft shim
        if ! iptables -t nat -C POSTROUTING -p udp --dport "$VPN_PORT" -j MASQUERADE --random-fully 2>/dev/null; then
             if ! iptables -t nat -A POSTROUTING -p udp --dport "$VPN_PORT" -j MASQUERADE --random-fully 2>/dev/null; then
                log_info "iptables shim failed; deploying native nft rule..."
                nft add rule ip nat POSTROUTING udp dport "$VPN_PORT" masquerade fully-random 2>/dev/null
             fi
        fi
    else
        log_warning "Reverting Source Port Randomization..."
        
        # 1. Remove from iptables
        iptables -t nat -D POSTROUTING -p udp --dport "$VPN_PORT" -j MASQUERADE --random-fully 2>/dev/null
        
        # 2. Flush specific nft rule if it exists (Atomic Removal)
        # Note: In a production refactor, we usually flush the specific handle, 
        # but for simplicity, we target the rule definition.
        nft delete rule ip nat POSTROUTING udp dport "$VPN_PORT" masquerade fully-random 2>/dev/null
    fi
}

function check_source_port_randomization() {
    local INTENT=$1
    local VPN_PORT="${ONYX_VPN_PORT:-51820}"

    # Check both subsystems for the 'fully-random' flag
    local IPT_CHECK=$(iptables -t nat -S POSTROUTING 2>/dev/null | grep -q "random-fully" && echo 0 || echo 1)
    local NFT_CHECK=$(nft list table ip nat 2>/dev/null | grep -q "masquerade fully-random" && echo 0 || echo 1)
    
    # If either subsystem has it active, STATUS is 0
    local STATUS=$([[ $IPT_CHECK -eq 0 || $NFT_CHECK -eq 0 ]] && echo 0 || echo 1)

    # SYNC LOGIC:
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    return 1
}