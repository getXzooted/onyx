# modules/network/hardening_rules.sh

function apply_log_martians() {
    local INTENT=$1
    # 1 is active (Onyx Default), 0 is disabled (Linux Default)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")
    
    log_step "Setting Martian Packet Logging to $VAL..."
    sysctl -w net.ipv4.conf.all.log_martians=$VAL > /dev/null
}

function check_log_martians() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv4.conf.all.log_martians)

    # SYNC LOGIC:
    # 1. Intent is 'true' and logging is active (1) -> Sync (0)
    # 2. Intent is 'false' and logging is inactive (0) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "1" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}