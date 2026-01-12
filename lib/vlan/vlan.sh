#!/bin/bash
# LIB: VLAN CLI Controller - Multi-SSID Edition

source "$ONYX_ROOT/modules/vlan/engine.sh"

function vlan_sync_all() {
    log_header "SYNCHRONIZING VLAN & WIRELESS SEGMENTS"
    
    # 1. Clear old Virtual DHCP configs to prevent stale leases
    rm -f /etc/dnsmasq.d/10-vlan-*.conf

    # 2. Extract and Iterate Segments from onyx.yml
    local SEGMENTS=$(yq e '.networks.segments[].name' "$ONYX_YAML")
    
    for NAME in $SEGMENTS; do
        # Extract YAML values for this segment
        local ID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .id" "$ONYX_YAML")
        local SSID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .ssid" "$ONYX_YAML")
        local SUBNET=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .subnet" "$ONYX_YAML")
        local RANGE=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .dhcp_range" "$ONYX_YAML")
        local ISOLATED=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .isolated" "$ONYX_YAML")

        # Step A: Create Kernel Interface & Assign IP
        vlan_apply_state "$NAME" "$ID" "$SUBNET" "$RANGE"

        # Step B: If SSID is defined, prepare the hostapd bridge
        if [[ "$SSID" != "null" ]]; then
            log_step "Mapping $NAME to Wireless SSID: $SSID"
            # Logic here will eventually append to the hostapd template
        fi

        # Step C: Enforcement - If isolated=true, apply firewall barrier
        if [[ "$ISOLATED" == "true" ]]; then
            log_info "Enforcing isolation for $NAME..."
            build_rule FORWARD -i "$NAME" -o "$ONYX_LAN_IFACE" -j DROP
        fi
    done

    systemctl restart dnsmasq
    log_success "All VLAN segments synchronized and hardened."
}

case "$1" in
    sync)   vlan_sync_all ;;
    *)      echo "Usage: onyx vlan {sync}" ;;
esac