function apply_vlan_isolation() {
    local INTENT=$1
    # Agnostic: Pull the list of VLANs; fallback to a default if empty
    local VLAN_LIST="${ONYX_VLAN_LIST:-vlan20 guest_vlan}"
    local DEST_IFACE="${ONYX_LAN_IFACE:-uap0}"

    for VLAN in $VLAN_LIST; do
        if [[ "$INTENT" == "true" ]]; then
            log_step "Enforcing Isolation: $VLAN -> $DEST_IFACE..."
            build_rule FORWARD -i "$VLAN" -o "$DEST_IFACE" -j DROP
        else
            log_warning "Reverting Isolation: $VLAN -> $DEST_IFACE..."
            delete_rule FORWARD -i "$VLAN" -o "$DEST_IFACE" -j DROP
        fi
    done
}

function check_vlan_isolation() {
    local INTENT=$1
    local VLAN_LIST="${ONYX_VLAN_LIST:-vlan20 guest_vlan}"
    local DEST_IFACE="${ONYX_LAN_IFACE:-uap0}"
    local MASTER_STATUS=0

    for VLAN in $VLAN_LIST; do
        # Verify if the specific isolation rule is present
        iptables -C FORWARD -i "$VLAN" -o "$DEST_IFACE" -j DROP &>/dev/null
        local STATUS=$?

        # Drift Detection Logic per VLAN
        if [[ "$INTENT" == "true" && $STATUS -ne 0 ]]; then MASTER_STATUS=1; fi
        if [[ "$INTENT" == "false" && $STATUS -eq 0 ]]; then MASTER_STATUS=1; fi
    done

    # If any single VLAN in the list is out of sync, the whole check fails (returns 1)
    return $MASTER_STATUS
}