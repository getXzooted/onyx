function apply_geo_blocking() {
    local INTENT=$1
    local LIST="/etc/onyx/firewall/geo_block.list"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Sovereign Geoblock (ipset)..."

        # 1. Ensure Dependencies & Directories exist via Asset Engine
        # We assume 'ipset_binary' and 'firewall_dir' are defined in assets.yml
        asset_get "firewall_dir"
        asset_get "geoblock_high_risk"

        if [[ -f "$LIST" ]]; then
            # 2. Create high-performance memory set
            ipset create onyx_geoblock hash:net -exist

            # 3. Atomic Reload: Flush and populate memory set
            ipset flush onyx_geoblock
            while read -r range; do
                [[ -z "$range" || "$range" == \#* ]] && continue
                ipset add onyx_geoblock "$range" -exist
            done < "$LIST"

            # 4. Inject the single lookup rule with Onyx label
            build_rule INPUT -m set --match-set onyx_geoblock src -j DROP \
                -m comment --comment "ONYX_GEOBLOCK"
            
            log_success "Geoblock active: $(ipset list onyx_geoblock | grep -c '/') ranges in memory."
        else
            log_error "Geoblock list missing at $LIST. Asset retrieval failed."
            return 1
        fi
    else
        log_warning "Deactivating Sovereign Geoblock..."
        # Remove the firewall rule using its unique label
        delete_rule INPUT -m set --match-set onyx_geoblock src -j DROP \
            -m comment --comment "ONYX_GEOBLOCK"
        # Destroy the memory set to free RAM
        ipset destroy onyx_geoblock 2>/dev/null
    fi
}

function check_geo_blocking() {
    local INTENT=$1
    
    # 1. Check if the ipset physically exists in memory
    local SET_EXISTS=$(ipset list onyx_geoblock &>/dev/null && echo 0 || echo 1)
    
    # 2. Check for the labeled firewall rule
    iptables -S INPUT 2>/dev/null | grep -q "ONYX_GEOBLOCK"
    local RULE_EXISTS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and BOTH set + rule exist -> Sync (0)
    if [[ "$INTENT" == "true" && $SET_EXISTS -eq 0 && $RULE_EXISTS -eq 0 ]]; then return 0; fi
    
    # 2. Intent is 'false' and BOTH are gone -> Sync (0)
    if [[ "$INTENT" == "false" && $SET_EXISTS -ne 0 && $RULE_EXISTS -ne 0 ]]; then return 0; fi

    # Otherwise, system has drifted (e.g. set exists but rule is missing)
    return 1
}