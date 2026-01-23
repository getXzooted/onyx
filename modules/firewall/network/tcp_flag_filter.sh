function apply_tcp_flag_filter() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing TCP Flag Filter (Dropping Null/Xmas Scans)..."
        # Null Scan: No flags set
        build_rule INPUT -p tcp --tcp-flags ALL NONE -j DROP
        # Xmas Scan: All flags set (lighting it up like a Christmas tree)
        build_rule INPUT -p tcp --tcp-flags ALL ALL -j DROP
    else
        log_warning "Reverting TCP Flag Filter..."
        delete_rule INPUT -p tcp --tcp-flags ALL NONE -j DROP
        delete_rule INPUT -p tcp --tcp-flags ALL ALL -j DROP
    fi
}

function check_tcp_flag_filter() {
    local INTENT=$1

    # Check for both flag blocks
    iptables -C INPUT -p tcp --tcp-flags ALL NONE -j DROP &>/dev/null && \
    iptables -C INPUT -p tcp --tcp-flags ALL ALL -j DROP &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and rules exist (STATUS 0) -> Sync (0)
    # 2. Intent is 'false' and rules are missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state does not match YAML intent (Drift)
    return 1
}