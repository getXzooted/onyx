function apply_ignore_redirects() {
    local INTENT=$1
    # 0 is ignore (Onyx Default), 1 is accept (Linux Default)
    local VAL=$([[ "$INTENT" == "true" ]] && echo "0" || echo "1")
    
    log_step "Setting ICMP Redirect Acceptance to $VAL..."
    sysctl -w net.ipv4.conf.all.accept_redirects=$VAL > /dev/null
    sysctl -w net.ipv4.conf.default.accept_redirects=$VAL > /dev/null
}

function check_ignore_redirects() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv4.conf.all.accept_redirects)

    # SYNC LOGIC:
    # 1. Intent is 'true' (ignore) and kernel says '0' (ignoring) -> Sync (0)
    # 2. Intent is 'false' (accept) and kernel says '1' (accepting) -> Sync (0)
    if [[ "$INTENT" == "true" && "$CURRENT" == "0" ]]; then return 0; fi
    if [[ "$INTENT" == "false" && "$CURRENT" == "1" ]]; then return 0; fi

    # Otherwise, system state has drifted from the desired YAML intent
    return 1
}