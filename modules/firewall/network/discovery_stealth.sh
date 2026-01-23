function apply_discovery_stealth() {
    local INTENT=$1

    if [[ "$INTENT" == "true" ]]; then
        log_step "Enforcing Discovery Stealth (Blocking mDNS/LLMNR)..."
        # Kill outbound broadcasts to remain invisible to scanners
        build_rule OUTPUT -p udp -m multiport --dports 5353,5355 -j DROP
    else
        log_warning "Reverting Discovery Stealth (Restoring Discovery)..."
        # Re-allow discovery if needed for local networking (like AirPlay/Chromecast)
        delete_rule OUTPUT -p udp -m multiport --dports 5353,5355 -j DROP
    fi
}

function check_discovery_stealth() {
    local INTENT=$1

    # Verify if the drop rule is physically present in the OUTPUT chain
    iptables -C OUTPUT -p udp -m multiport --dports 5353,5355 -j DROP &>/dev/null
    local STATUS=$?

    # SYNC LOGIC:
    # 1. Intent is 'true' and rule exists (STATUS 0) -> Sync (0)
    # 2. Intent is 'false' and rule is missing (STATUS non-zero) -> Sync (0)
    if [[ "$INTENT" == "true" && $STATUS -eq 0 ]]; then return 0; fi
    if [[ "$INTENT" == "false" && $STATUS -ne 0 ]]; then return 0; fi

    # Otherwise, system state does not match YAML intent (Drift)
    return 1
}