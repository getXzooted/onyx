#!/bin/bash
# LIB: VLAN CLI Controller - Multi-SSID Master Sync

source "$ONYX_ROOT/modules/vlan/engine.sh"

function vlan_sync_all() {
    log_header "BOOTSTRAPPING SOVEREIGN WIRELESS"

    # 1. THE "USER FIX": Unmask and Enable
    log_step "Ensuring Hostapd service is unmasked and enabled..."
    systemctl unmask hostapd &> /dev/null
    systemctl enable hostapd &> /dev/null
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

    # 2. PHYSICAL ANCHOR: Initialize Parent (uap0)
    local PARENT=$(yq e '.networks.parent' "$ONYX_YAML")
    local PHY_INT=$(ls /sys/class/net | grep ^wl | head -n 1)
    [[ -z "$PHY_INT" ]] && PHY_INT="wlan0"

    log_step "Initializing Parent Interface $PARENT on hardware $PHY_INT..."
    
    # Create the systemd override to ensure uap0 exists before hostapd starts
    mkdir -p /etc/systemd/system/hostapd.service.d
    cat <<EOF > /etc/systemd/system/hostapd.service.d/override.conf
[Service]
ExecStartPre=-/usr/sbin/iw dev $PHY_INT interface add $PARENT type __ap
ExecStartPre=-/usr/sbin/ip link set $PARENT up
EOF
    systemctl daemon-reload

    # 3. CONFIG RESET: Prepare hostapd.conf for Multi-SSID
    # We clear the file and write the primary radio configuration first
    log_step "Resetting Multi-SSID configuration..."
    rm -f /etc/dnsmasq.d/10-vlan-*.conf
    # Initialize hostapd.conf with the primary hardware settings
    vlan_initialize_hostapd "$PARENT"

    # 4. SEGMENT LOOP: Build VLANs and BSSIDs
    local SEGMENTS=$(yq e '.networks.segments[].name' "$ONYX_YAML")
    for NAME in $SEGMENTS; do
        local ID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .id" "$ONYX_YAML")
        local SSID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .ssid" "$ONYX_YAML")
        local SUBNET=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .subnet" "$ONYX_YAML")
        local RANGE=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .dhcp_range" "$ONYX_YAML")
        local ISOLATED=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .isolated" "$ONYX_YAML")

        # Create tagged kernel pipe
        vlan_apply_hardware "$NAME" "$ID" "$SUBNET"
        vlan_generate_dhcp "$NAME" "$RANGE"

        # Broadcast if SSID exists
        if [[ "$SSID" != "null" ]]; then
            local PASS=$(yq e '.wifi_password' "$ONYX_YAML")
            vlan_update_wireless "$NAME" "$SSID" "$PASS"
        fi

        # Firewall Barrier
        if [[ "$ISOLATED" == "true" ]]; then
            build_rule FORWARD -i "$NAME" -o "$ONYX_LAN_IFACE" -j DROP
        fi
    done

    # 5. RESTART SERVICES
    systemctl restart dnsmasq
    systemctl restart hostapd
    log_success "Wireless Stack Synchronized and Live."
}

case "$1" in
    sync)   vlan_sync_all ;;
    *)      echo "Usage: onyx vlan sync" ;;
esac