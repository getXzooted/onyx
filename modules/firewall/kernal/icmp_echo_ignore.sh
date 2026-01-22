# modules/network/hardening_rules.sh

function apply_icmp_echo_ignore() {
    local INTENT=$1
    
    # 1 is ignore (Onyx Default), 0 is respond (Linux Default)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing ICMP Stealth (Broadcast Ignore: 1)..."
    else
        log_warning "Reverting ICMP Stealth (Broadcast Ignore: 0)..."
    fi

    sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=$VAL > /dev/null
    sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=$VAL > /dev/null
}

function check_icmp_echo_ignore() {
    local INTENT=$1
    
    local CUR_BROADCAST=$(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts)
    local CUR_BOGUS=$(sysctl -n net.ipv4.icmp_ignore_bogus_error_responses)

    # SYNC LOGIC:
    # 1. Intent is 'true' and both are in stealth mode (1) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CUR_BROADCAST" == "1" && "$CUR_BOGUS" == "1" ]]; then return 0; fi
    
    # 2. Intent is 'false' and both are in standard mode (0) -> Sync (0)
    if [[ "$INTENT" == "false" && "$CUR_BROADCAST" == "0" && "$CUR_BOGUS" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}