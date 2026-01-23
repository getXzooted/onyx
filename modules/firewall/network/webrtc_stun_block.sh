function apply_webrtc_stun_block() {
    local INTENT=$1
    # Standard STUN/TURN ports: 3478 (STUN/TURN), 19302 (Google STUN), 5349 (STUN over TLS)
    local PORTS="3478,19302,5349"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing WebRTC Lockdown (Blocking STUN/TURN: $PORTS)..."
        build_rule OUTPUT -p udp -m multiport --dports "$PORTS" -j DROP
    else
        log_warning "Reverting WebRTC Lockdown (Restoring STUN/TURN)..."
        delete_rule OUTPUT -p udp -m multiport --dports "$PORTS" -j DROP
    fi
}

function check_webrtc_stun_block() {
    local INTENT=$1
    local PORTS="3478,19302,5349"

    # Verify if the drop rule for these specific ports is in the OUTPUT chain
    iptables -C OUTPUT -p udp -m multiport --dports "$PORTS" -j DROP &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and rule exists (STATUS 0) -> Sync (0)
    # 2. Intent is 'false' and rule is missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted
    return 1
}