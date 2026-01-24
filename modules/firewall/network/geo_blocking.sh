function apply_geo_blocking() {
    local INTENT=$1
    local LIST="/etc/onyx/firewall/geo_block.list"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Sovereign Geoblock (Syncing Bridge)..."

        # 1. JIT Prerequisites
        asset_get "ipset"
        asset_get "ipset_bridge"
        asset_get "firewall_dir"
        asset_get "geoblock_high_risk"

        # 2. Kernel Module Bridge
        # We remove 2>/dev/null here so you can see if the kernel rejects the module
        modprobe ip_set
        modprobe ip_set_hash_net
        if ! modprobe xt_set; then
            log_error "Kernel Failure: 'xt_set' module not found. Geoblock cannot link to iptables."
            return 1
        fi

        if [[ -f "$LIST" ]]; then
            ipset create onyx_geoblock hash:net -exist
            ipset flush onyx_geoblock

            log_info "Injecting IP ranges into kernel..."
            sed -e "s/^/add onyx_geoblock /" "$LIST" | ipset restore
            
            # 3. Inject Labeled Rule
            build_rule INPUT -m set --match-set onyx_geoblock src -j DROP \
                -m comment --comment "ONYX_GEOBLOCK"
            
            log_success "Geoblock state synchronized."
        fi
    else
        log_warning "Deactivating Geoblock..."
        delete_rule INPUT -m set --match-set onyx_geoblock src -j DROP \
            -m comment --comment "ONYX_GEOBLOCK"
        ipset destroy onyx_geoblock 2>/dev/null
    fi
}

function check_geo_blocking() {
    local INTENT=$1
    
    # Audit 1: Verify the set exists and has members
    local MEMBER_COUNT=$(ipset list onyx_geoblock 2>/dev/null | grep -c '/')
    
    # Audit 2: Verify the labeled rule is in the live chain
    iptables -S INPUT 2>/dev/null | grep -q "ONYX_GEOBLOCK"
    local RULE_EXISTS=$?

    # SYNC LOGIC:
    if [[ "$INTENT" == "true" ]]; then
        # Rule exists AND set is populated
        [[ $RULE_EXISTS -eq 0 && $MEMBER_COUNT -gt 0 ]] && return 0 || return 1
    fi

    if [[ "$INTENT" == "false" ]]; then
        # Rule is gone AND set is gone/empty
        [[ $RULE_EXISTS -ne 0 && $MEMBER_COUNT -eq 0 ]] && return 0 || return 1
    fi

    return 1
}