function apply_tcp_timestamps() {
    local INTENT=$1
    
    if [[ "$INTENT" == "true" ]]; then
        log_step "Applying TCP Timestamp Stealth (Anti-Fingerprinting)..."
        # Disable timestamps to hide OS-specific uptime and timing signatures
        sysctl -w net.ipv4.tcp_timestamps=0 > /dev/null
        # Ensure window scaling remains on for performance (Onyx Standard)
        sysctl -w net.ipv4.tcp_window_scaling=1 > /dev/null
    else
        log_warning "Reverting TCP Timestamps to Linux Defaults..."
        # Standard Linux behavior is typically enabled (1)
        sysctl -w net.ipv4.tcp_timestamps=1 > /dev/null
        sysctl -w net.ipv4.tcp_window_scaling=1 > /dev/null
    fi
}

function check_tcp_timestamps() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv4.tcp_timestamps)

    # SYNC LOGIC:
    # 1. Intent is 'true' (stealth) and timestamps are disabled (0) -> Sync (0)
    # 2. Intent is 'false' (standard) and timestamps are enabled (1) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "0" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "1" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}