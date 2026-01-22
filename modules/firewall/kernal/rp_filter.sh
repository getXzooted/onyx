function apply_rp_filter() {
    local INTENT=$1
    # 1 is Strict Filtering (Onyx Default), 0 is Disabled (Linux Default)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")
    
    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Anti-Spoofing (Strict RP Filter: 1)..."
    else
        log_warning "Reverting Anti-Spoofing (Standard RP Filter: 0)..."
    fi

    # Apply to both 'all' and 'default' to ensure consistency for future interfaces
    sysctl -w net.ipv4.conf.all.rp_filter=$VAL > /dev/null
    sysctl -w net.ipv4.conf.default.rp_filter=$VAL > /dev/null
}

function check_rp_filter() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv4.conf.all.rp_filter)

    # SYNC LOGIC:
    # 1. Intent is 'true' and filtering is Strict (1) -> Sync (0)
    # 2. Intent is 'false' and filtering is Disabled (0) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "1" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}