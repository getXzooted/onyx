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

    # 1. Generate Hostapd Config
    log_step "Writing Hostapd config for SSID: $SSID..."
    HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
    
    if [ ! -s "$HOSTAPD_CONF" ]; then
        log_warning "No existing hostapd config found. Creating default."
        
        cat <<EOF > /etc/hostapd/hostapd.conf
interface=$IFACE
ssid=$SSID
wpa_passphrase=$PASS
driver=nl80211
hw_mode=g
channel=6
wpa=2
wpa_key_mgmt=WPA-PSK


country_code=US
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
        log_success "Created hostapd config at $HOSTAPD_CONF"
    else
        log_info "Using existing hostapd config at $HOSTAPD_CONF"
    fi

    # We must point hostapd to this config file specifically
    DAEMON_CONF="/etc/default/hostapd"
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > "$DAEMON_CONF"

    systemctl unmask hostapd &> /dev/null
    systemctl enable hostapd &> /dev/null

    # 2. Interface Hardware Lock    
    log_step "Initializing $IFACE on $IP/$MASK..."
    
    # Find the physical interface name (e.g., wlan0)
    # We look for the first interface starting with 'wl' (wireless)
    PHY_INT=$(ls /sys/class/net | grep ^wl | head -n 1)
    
    # Fallback to wlan0 if detection fails
    if [ -z "$PHY_INT" ]; then PHY_INT="wlan0"; fi

    # Tell NetworkManager to ignore uap0
    # This ensures the OS respects our custom IP assignment and doesn't wipe it.
    if [ -d "/etc/NetworkManager/conf.d" ]; then
        log_step "Configuring NetworkManager to ignore $IFACE..."
        echo -e "[keyfile]\nunmanaged-devices=interface-name:$IFACE" > /etc/NetworkManager/conf.d/99-onyx-$IFACE.conf
        systemctl reload NetworkManager &> /dev/null
    fi
    
    ip link set "$IFACE" down 2>/dev/null
    iw dev "$PHY_INT" interface add "$IFACE" type __ap 2>/dev/null
    ip addr add "$IP/$MASK" dev "$IFACE"
    ip link set "$IFACE" up

    mkdir -p /etc/systemd/system/hostapd.service.d
    
    echo "[Service]" > /etc/systemd/system/hostapd.service.d/override.conf
    
    # 1. Create the virtual interface (Ignore error if exists)
    echo "ExecStartPre=-/usr/sbin/iw dev "$PHY_INT" interface add $IFACE type __ap" >> /etc/systemd/system/hostapd.service.d/override.conf

    # 2. ASSIGN GATEWAY IP (The Missing Link)
    # This matches the default RaspAP DHCP range (10.3.141.x)
    echo "ExecStartPre=-/usr/sbin/ip addr add $IP/$MASK dev $IFACE" >> /etc/systemd/system/hostapd.service.d/override.conf

    # 3. Bring the interface UP
    echo "ExecStartPre=-/usr/sbin/ip link set $IFACE up" >> /etc/systemd/system/hostapd.service.d/override.conf

    systemctl daemon-reload

    systemctl restart hostapd &> /dev/null
    
    if systemctl is-active hostapd &> /dev/null; then
        log_success "WiFi Service (hostapd) is RUNNING."
    else
        log_error "WiFi Service failed to start. Check /etc/hostapd/hostapd.conf"
    fi

    # Smart DNS Prioritization
    # Order: 1. Unbound -> 2. User Custom -> 3. VPN Config -> 4. Cloudflare
    
    ONYX_DHCP="/etc/dnsmasq.d/onyx-hotspot.conf"
    WG_CONF="/etc/wireguard/wg0.conf"
    
    log_step "Calculating DNS Priority..."

    # 0. Extract DNS from VPN Config (if it exists)
    # Catches "DNS = 10.64.0.1" from wg0.conf. Cleans spaces and takes the first IP if multiple exist.
    VPN_DNS_FOUND=$(grep -i "^DNS" "$WG_CONF" 2>/dev/null | head -n 1 | awk -F '=' '{print $2}' | cut -d ',' -f 1 | tr -d '[:space:]')

    # 1. Determine Upstream
    if systemctl is-active unbound &>/dev/null; then
        # PRIORITY 1: Unbound
        DNS_UPSTREAM="127.0.0.1#5335"
        log_info "DNS Mode: Unbound (Recursive)"

    elif [ -n "$ONYX_DNS_CUSTOM" ]; then
        # PRIORITY 2: User Custom (from onyx.yml)
        DNS_UPSTREAM="$ONYX_DNS_CUSTOM"
        log_info "DNS Mode: User Custom ($DNS_UPSTREAM)"

    elif [ -n "$VPN_DNS_FOUND" ]; then
        # PRIORITY 3: VPN Provider (Extracted from wg0.conf)
        DNS_UPSTREAM="$VPN_DNS_FOUND"
        log_info "DNS Mode: VPN Provider ($DNS_UPSTREAM)"

    else
        # PRIORITY 4: Last Resort
        DNS_UPSTREAM="1.1.1.1"
        log_info "DNS Mode: Fallback (Cloudflare)"
    fi

    # 3. Generate Dnsmasq Config
    log_step "Directing DHCP clients to Unbound at $IP..."
    cat <<EOF > $ONYX_DHCP
interface=$IFACE
dhcp-range=$DHCP_START,$DHCP_END,12h
dhcp-option=6,$IP
no-resolv
server=$DNS_UPSTREAM
EOF

    systemctl restart dnsmasq
    log_success "Native Hotspot Active: $IFACE is live at $IP"
}

network_native_hotspot