# modules/network/hardening_rules.sh

function apply_tcp_syncookies() {
    local INTENT=$1
    # 1 is active (Onyx Default), 0 is disabled (Linux Default)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")
    
    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Flood Protection (TCP SYN Cookies: 1)..."
    else
        log_warning "Reverting Flood Protection (TCP SYN Cookies: 0)..."
    fi

    sysctl -w net.ipv4.tcp_syncookies=$VAL > /dev/null
}

function check_tcp_syncookies() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv4.tcp_syncookies)

    # SYNC LOGIC:
    # 1. Intent is 'true' and syncookies are active (1) -> Sync (0)
    # 2. Intent is 'false' and syncookies are inactive (0) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "1" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}