function apply_geo_blocking() {
    local INTENT=$1
    local LIST="/etc/onyx/firewall/geo_block.list"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Sovereign Geoblock (High-Performance)..."

        # 1. JIT Prerequisites
        asset_get "ipset"
        asset_get "firewall_dir"
        asset_get "geoblock_high_risk"

        # 2. Kernel Bridge: Ensure modules are active for Pi hardware
        modprobe ip_set 2>/dev/null
        modprobe ip_set_hash_net 2>/dev/null
        modprobe xt_set 2>/dev/null

        if [[ -f "$LIST" ]]; then
            # 3. Memory Set Initialization
            ipset create onyx_geoblock hash:net -exist
            ipset flush onyx_geoblock

            # 4. ATOMIC RESTORE (The "Zero-Aware" Fix)
            # Converts CIDR list to ipset commands and injects them in one shot
            log_info "Loading IP ranges into kernel memory..."
            sed -e "s/^/add onyx_geoblock /" "$LIST" | ipset restore 2>/dev/null
            
            # 5. Labeled Firewall Injection
            build_rule INPUT -m set --match-set onyx_geoblock src -j DROP \
                -m comment --comment "ONYX_GEOBLOCK"
            
            log_success "Geoblock active: $(ipset list onyx_geoblock | grep -c '/') ranges loaded."
        else
            log_error "Geoblock source missing at $LIST."
            return 1
        fi
    else
        log_warning "Deactivating Sovereign Geoblock..."
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