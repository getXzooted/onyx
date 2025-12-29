#!/bin/bash
# MODULE: Network > Native Hotspot
# Manages hostapd and dnsmasq via Environment Variables.

function network_native_hotspot() {
    log_header "CONFIGURING NATIVE HOTSPOT"
    
    # Use environment variables with fallbacks to vars.sh defaults
    local IFACE="${ONYX_HOTSPOT_IFACE:-uap0}"
    local IP="${ONYX_HOTSPOT_IP:-10.3.141.1}"
    local MASK="${ONYX_HOTSPOT_MASK:-24}"
    local SSID="${ONYX_WIFI_SSID:-Onyx_Gateway}"
    local PASS="${ONYX_WIFI_PASSWORD:-ChangeMe123}"
    local DHCP_START="${ONYX_DHCP_START:-10.3.141.50}"
    local DHCP_END="${ONYX_DHCP_END:-10.3.141.255}"

    # 1. Interface Hardware Lock
    log_step "Initializing $IFACE on $IP/$MASK..."
    PHY_INT=$(ls /sys/class/net | grep ^wl | head -n 1)
    
    ip link set "$IFACE" down 2>/dev/null
    iw dev "$PHY_INT" interface add "$IFACE" type __ap 2>/dev/null
    ip addr add "$IP/$MASK" dev "$IFACE"
    ip link set "$IFACE" up

    # 2. Generate Hostapd Config
    log_step "Writing Hostapd config for SSID: $SSID..."
    cat <<EOF > /etc/hostapd/hostapd.conf
interface=$IFACE
ssid=$SSID
wpa_passphrase=$PASS
driver=nl80211
hw_mode=g
channel=6
wpa=2
wpa_key_mgmt=WPA-PSK
EOF

    # 3. Generate Dnsmasq Config
    log_step "Directing DHCP clients to Unbound at $IP..."
    cat <<EOF > /etc/dnsmasq.d/onyx-hotspot.conf
interface=$IFACE
dhcp-range=$DHCP_START,$DHCP_END,12h
dhcp-option=6,$IP
no-resolv
server=127.0.0.1#5335
EOF

    systemctl unmask hostapd
    systemctl restart hostapd dnsmasq
    log_success "Native Hotspot Active: $IFACE is live at $IP"
}

network_native_hotspot