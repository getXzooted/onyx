function apply_geo_blocking() {
    local INTENT=$1
    local LIST="/etc/onyx/firewall/geo_block.list"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Sovereign Geoblock (ipset High-Performance)..."

        # 1. JIT Prerequisites (using your Asset Engine logic)
        # asset_get "ipset"
         asset_get "geoblock_high_risk"

        # 2. THE FIX: Force the bridge modules to wake up
        modprobe ip_set 2>/dev/null
        #modprobe xt_set 2>/dev/null

        if [[ -f "$LIST" ]]; then
            # 3. Standard ipset logic
            ipset create onyx_geoblock hash:net -exist
            ipset flush onyx_geoblock

            log_info "Loading IP ranges into kernel memory..."
            # Using your while loop as requested
            while read -r range; do
                [[ -z "$range" || "$range" == \#* ]] && continue
                ipset add onyx_geoblock "$range" -exist
            done < "$LIST"

            # 4. Inject Labeled Rule
            # Adding the comment ensures build_rule matches perfectly
            build_rule INPUT -m set --match-set onyx_geoblock src -j DROP \
                -m comment --comment "ONYX_GEOBLOCK"
            
            log_success "Geoblock active: $(ipset list onyx_geoblock | grep -c '/') ranges loaded."
        fi
    else
        log_warning "Deactivating Geoblock..."
        delete_rule INPUT -m set --match-set onyx_geoblock src -j DROP \
            -m comment --comment "ONYX_GEOBLOCK"
        ipset destroy onyx_geoblock 2>/dev/null
    fi
}

function check_geo_blocking() {
    # 1. Verify the set exists and is populated
    local COUNT=$(ipset list onyx_geoblock 2>/dev/null | grep -c '/' || echo 0)
    
    # 2. THE FIX: Search for the label as a raw string. 
    # Do not wrap the search term in extra escaped quotes.
    iptables -S INPUT 2>/dev/null | grep -q ONYX_GEOBLOCK
    local RULE_STATUS=$?

    if [[ "$COUNT" -gt 0 ]] && [[ "$RULE_STATUS" -eq 0 ]]; then
        return 0
    fi
    
    return 1
}