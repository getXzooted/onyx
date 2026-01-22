function apply_icmp_ratelimit() {
    local INTENT=$1
    
    # 1000 is the standard rate limit for ICMP (Standard Defense)
    # 1 is to ignore bogus responses (Onyx Default), 0 is to process them (Linux Default)
    local BOGUS_VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")
    
    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing ICMP Recon Defense (Rate Limit: 1000, Ignore Bogus: 1)..."
        sysctl -w net.ipv4.icmp_ratelimit=1000 > /dev/null
        sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1 > /dev/null
    else
        log_warning "Reverting ICMP Recon Defense (Restoring Bogus Processing)..."
        # We maintain the standard rate limit but revert the bogus response policy
        sysctl -w net.ipv4.icmp_ratelimit=1000 > /dev/null
        sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=0 > /dev/null
    fi
}

function check_icmp_ratelimit() {
    local INTENT=$1
    local CURRENT_RL=$(sysctl -n net.ipv4.icmp_ratelimit)
    local CURRENT_BOGUS=$(sysctl -n net.ipv4.icmp_ignore_bogus_error_responses)

    # SYNC LOGIC:
    # 1. Intent is 'true': Limit is 1000 AND Bogus is ignored (1) -> Sync (0)
    # 2. Intent is 'false': Bogus is processed (0) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT_RL" == "1000" && "$CURRENT_BOGUS" == "1" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT_BOGUS" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}