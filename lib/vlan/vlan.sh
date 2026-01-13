#!/bin/bash
# LIB: VLAN CLI Controller - Master Sync

source "$ONYX_ROOT/modules/vlan/engine.sh"

function vlan_sync_all() {
    log_header "SYNCHRONIZING SOVEREIGN NETWORK"

    # 1. Service Permissions (Absorbed from Hotspot.sh)
    systemctl unmask hostapd &> /dev/null
    systemctl enable hostapd &> /dev/null
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

    # 2. Anchor the Parent Interface
    local PARENT=$(yq e '.networks.parent' "$ONYX_YAML")
    local PARENT_IP=$(yq e '.hotspot_ip' "$ONYX_YAML")
    vlan_bootstrap_hardware "$PARENT" "$PARENT_IP"

    # 3. Stage the Multi-SSID Configuration
    vlan_init_hostapd "$PARENT"
    rm -f /etc/dnsmasq.d/10-vlan-*.conf

    # 4. Loop through Segments
    local SEGMENTS=$(yq e '.networks.segments[].name' "$ONYX_YAML")
    for NAME in $SEGMENTS; do
        local SSID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .ssid" "$ONYX_YAML")
        local RANGE=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .dhcp_range" "$ONYX_YAML")
        local SUBNET=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .subnet" "$ONYX_YAML")
        
        vlan_generate_dhcp "$NAME" "$RANGE"

        if [[ "$SSID" != "null" ]]; then
            # Map SSID to Hostapd BSS
            local PASS=$(yq e '.wifi_password' "$ONYX_YAML")
            vlan_update_wireless "$NAME" "$SSID" "$PASS"
        else
            # Kernel-only Tagging
            local ID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .id" "$ONYX_YAML")
            vlan_apply_hardware "$NAME" "$ID" "$SUBNET"
        fi
    done

    # 5. Atomic Restart
    systemctl restart dnsmasq
    systemctl restart hostapd
    log_success "Sovereign Stack is now ACTIVE with Multi-SSID support."
}

case "$1" in
    sync) vlan_sync_all ;;
    *)    echo "Usage: onyx vlan sync" ;;
esac