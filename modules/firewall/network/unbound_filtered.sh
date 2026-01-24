# modules/network/hardening_rules.sh

function apply_unbound_filtered() {
    local INTENT=$1
    local RAW_TARGET="/etc/unbound/unbound.conf.d/sentinel_raw.tmp"
    local FINAL_CONF="/etc/unbound/unbound.conf.d/onyx-sentinel.conf"

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing DNS Sentinel (Blocklist Sync)..."
        
        # 1. Fetch raw assets via Engine (No processing inside asset_get)
        asset_get "sentinel_dns"
        
        # 2. Worker-Level Processing: Convert raw hosts to Unbound 'refuse' rules
        if [[ -f "$RAW_TARGET" ]]; then
            log_info "Processing raw host list into Sovereign definitions..."
            echo "server:" > "$FINAL_CONF"
            # Extract 0.0.0.0 entries and format for Unbound
            grep "^0.0.0.0" "$RAW_TARGET" | awk '{print "    local-zone: \""$2"\" refuse"}' >> "$FINAL_CONF"
            
            # 3. Apply changes via service restart
            systemctl restart unbound
            log_success "DNS Sentinel active: $(grep -c "refuse" "$FINAL_CONF") domains blocked."
        fi
    else
        log_warning "Deactivating DNS Sentinel..."
        rm -f "$FINAL_CONF"
        systemctl restart unbound
    fi
}

function check_unbound_filtered() {
    local INTENT=$1
    local FINAL_CONF="/etc/unbound/unbound.conf.d/onyx-sentinel.conf"

    # Verify if the processed blocklist exists and has content
    local STATUS=$([[ -s "$FINAL_CONF" ]] && echo 0 || echo 1)

    # SYNC LOGIC:
    # 1. Intent is 'true' and blocklist exists -> Sync (0)
    # 2. Intent is 'false' and blocklist is gone -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state has drifted
    return 1
}