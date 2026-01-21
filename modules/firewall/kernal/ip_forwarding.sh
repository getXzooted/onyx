function apply_ip_forwarding() {
    local INTENT=$1
    # 1 is active (Router Mode), 0 is disabled (Standard Client)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")
    
    log_step "Setting IP Forwarding to $VAL..."
    sysctl -w net.ipv4.ip_forward=$VAL > /dev/null
}

function check_ip_forwarding() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv4.ip_forward)

    # SYNC LOGIC:
    # 1. Intent is 'true' and forwarding is active (1) -> Sync (0)
    # 2. Intent is 'false' and forwarding is inactive (0) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "1" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}