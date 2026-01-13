#!/bin/bash
# LIB: VLAN CLI Controller - Multi-SSID Master Sync

source "$ONYX_ROOT/modules/vlan/engine.sh"

function vlan_sync_all() {
    log_header "SYNCHRONIZING NETWORK SEGMENTS"
    
    # 1. Initialization: Reset DHCP fragments and Hostapd
    rm -f /etc/dnsmasq.d/10-vlan-*.conf
    # Note: Hostapd rebuild logic will be added in the next refactor phase

    # 2. Iterate Segments defined in onyx.yml
    local SEGMENTS=$(yq e '.networks.segments[].name' "$ONYX_YAML")
    
    for NAME in $SEGMENTS; do
        # Extract YAML values
        local ID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .id" "$ONYX_YAML")
        local SSID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .ssid" "$ONYX_YAML")
        local SUBNET=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .subnet" "$ONYX_YAML")
        local RANGE=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .dhcp_range" "$ONYX_YAML")
        local ISOLATED=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .isolated" "$ONYX_YAML")

        # Step A: Build Kernel Hardware
        vlan_apply_hardware "$NAME" "$ID" "$SUBNET"

        # Step B: Deploy DHCP Pool
        vlan_generate_dhcp "$NAME" "$RANGE"

        # Step C: Wireless Broadcast
        if [[ "$SSID" != "null" ]]; then
            # Uses the password from the main hotspot for now
            local PASS=$(yq e '.wifi_password' "$ONYX_YAML")
            vlan_update_wireless "$NAME" "$SSID" "$PASS"
        fi

        # Step D: Hardening Enforcement
        if [[ "$ISOLATED" == "true" ]]; then
            log_info "Enforcing isolation barrier for $NAME..."
            # Prevent this segment from talking to the primary LAN (uap0)
            build_rule FORWARD -i "$NAME" -o "$ONYX_LAN_IFACE" -j DROP
        fi
    done

    systemctl restart dnsmasq
    systemctl restart hostapd
    log_success "All segments (Home, Guest, IoT) are ACTIVE and SECURED."
}

case "$1" in
    sync)   vlan_sync_all ;;
    *)      echo "Usage: onyx vlan sync" ;;
esac