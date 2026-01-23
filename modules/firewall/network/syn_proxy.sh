function apply_syn_proxy() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing SYN Proxy (Connection Handshake Protection)..."
        
        # 1. Engage the Proxy for untracked/invalid initial SYNs
        # We use the label-based logic for easy tracking
        build_rule FORWARD -p tcp -m state --state INVALID,UNTRACKED \
            -j SYNPROXY --sack-perm --timestamp --wscale 7 --mss 1460 \
            -m comment --comment "ONYX_SYN_PROXY"
            
        # 2. Drop the residue that fails the proxy handshake
        build_rule FORWARD -m state --state INVALID -j DROP \
            -m comment --comment "ONYX_INVALID_DROP"
    else
        log_warning "Reverting SYN Proxy Protection..."
        
        # Clean removal using the unique comments
        delete_rule FORWARD -p tcp -m state --state INVALID,UNTRACKED \
            -j SYNPROXY --sack-perm --timestamp --wscale 7 --mss 1460 \
            -m comment --comment "ONYX_SYN_PROXY"
            
        delete_rule FORWARD -m state --state INVALID -j DROP \
            -m comment --comment "ONYX_INVALID_DROP"
    fi
}

function check_syn_proxy() {
    local INTENT=$1

    # Search specifically for your custom tag in the FORWARD chain
    iptables -S FORWARD 2>/dev/null | grep -q "ONYX_SYN_PROXY"
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and the proxy tag exists -> Sync (0)
    # 2. Intent is 'false' and the proxy tag is missing -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted
    return 1
}