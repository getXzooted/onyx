function apply_no_send_redirects() {
    local INTENT=$1
    # 0 is do not send (Onyx Default), 1 is send (Linux Default)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "0" || echo "1")
    
    log_step "Setting ICMP Redirect Transmission to $VAL..."
    sysctl -w net.ipv4.conf.all.send_redirects=$VAL > /dev/null
    sysctl -w net.ipv4.conf.default.send_redirects=$VAL > /dev/null
}

function check_no_send_redirects() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv4.conf.all.send_redirects)

    # SYNC LOGIC:
    # 1. Intent is 'true' (suppress) and kernel says '0' (suppressing) -> Sync (0)
    # 2. Intent is 'false' (allow) and kernel says '1' (allowing) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "0" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "1" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}