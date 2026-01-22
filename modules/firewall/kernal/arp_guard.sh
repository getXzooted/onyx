function apply_arp_guard() {
    local INTENT=$1
    
    # Intent: true -> stealth mode (1/2), false -> standard mode (0/0)
    local IGNORE_VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")
    local ANNOUNCE_VAL=$([[ "$INTENT" == "true" ]] && echo "2" || echo "0")

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing ARP Guard (Neighbor Table Stealth: 1/2)..."
    else
        log_warning "Reverting ARP Guard to Linux Defaults (0/0)..."
    fi

    # Apply to 'all' and 'default' to ensure consistency across interfaces
    sysctl -w net.ipv4.conf.all.arp_ignore=$IGNORE_VAL > /dev/null
    sysctl -w net.ipv4.conf.default.arp_ignore=$IGNORE_VAL > /dev/null
    sysctl -w net.ipv4.conf.all.arp_announce=$ANNOUNCE_VAL > /dev/null
    sysctl -w net.ipv4.conf.default.arp_announce=$ANNOUNCE_VAL > /dev/null
}

function check_arp_guard() {
    local INTENT=$1
    
    # Current hardware state
    local CUR_IGNORE=$(sysctl -n net.ipv4.conf.all.arp_ignore)
    local CUR_ANNOUNCE=$(sysctl -n net.ipv4.conf.all.arp_announce)

    # SYNC LOGIC:
    # 1. Intent is 'true' and stealth is active (1 and 2) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CUR_IGNORE" == "1" && "$CUR_ANNOUNCE" == "2" ]]; then return 0; fi
    
    # 2. Intent is 'false' and defaults are restored (0 and 0) -> Sync (0)
    if [[ "$INTENT" == "false" && "$CUR_IGNORE" == "0" && "$CUR_ANNOUNCE" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}