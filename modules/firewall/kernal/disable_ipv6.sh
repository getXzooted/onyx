function apply_disable_ipv6() {
    local INTENT=$1
    # 1 is disabled (Onyx Default), 0 is enabled (Linux Default)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "1" || echo "0")
    
    log_step "Setting IPv6 Lockdown (disable_ipv6) to $VAL..."
    sysctl -w net.ipv6.conf.all.disable_ipv6=$VAL > /dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=$VAL > /dev/null
}

function check_disable_ipv6() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv6.conf.all.disable_ipv6)

    # SYNC LOGIC:
    # 1. Intent is 'true' (disable) and kernel says '1' (disabled) -> Sync (0)
    # 2. Intent is 'false' (enable) and kernel says '0' (enabled) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "1" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "0" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}