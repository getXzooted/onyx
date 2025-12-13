#!/bin/bash
# MODULE: System > RaspAP Installer
# Installs the Hotspot Web Interface and management tools.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function system_install_raspap() {
    log_header "INSTALLING RASPAP (HOTSPOT)"

    # Check if already installed to avoid re-running the heavy installer
    if [ -d "/var/www/html/raspap" ]; then
        log_warning "RaspAP appears to be installed. Skipping."
        return 0
    fi

    log_step "Downloading and running RaspAP installer..."
    
    # We use the official installer with flags to keep it quiet and clean.
    # --yes: Accept defaults
    # --no-reboot: We manage the reboot
    # --openvpn 0: We manage VPNs ourselves
    # --wireguard 0: We manage WireGuard ourselves
    curl -sL https://install.raspap.com | bash -s -- --yes --no-reboot --openvpn 0 --wireguard 0
    
    if [ $? -eq 0 ]; then
        log_success "RaspAP installed successfully."
    else
        log_error "RaspAP installation failed."
        exit 1
    fi

    # 2. FIX: Generate hostapd.conf if empty/missing
    # This fixes the "ConditionFileNotEmpty" error from your screenshot
    HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
    
    if [ ! -s "$HOSTAPD_CONF" ]; then
        log_warning "Hostapd config is missing/empty. Generating default..."
        
        # DYNAMICALLY FIND THE INTERFACE
        # We look for the first wireless interface that starts with 'w' (wlan0, wlan1, wlx...)
        WIFI_IFACE=$(ls /sys/class/net | grep -E '^w' | head -n 1)
        
        # Fallback to wlan0 if detection fails
        if [ -z "$WIFI_IFACE" ]; then WIFI_IFACE="wlan0"; fi
        
        log_info "Detected WiFi Interface: $WIFI_IFACE"
        
        cat <<EOF > "$HOSTAPD_CONF"
interface=$WIFI_IFACE
driver=nl80211
ssid=Onyx_Gateway
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=ChangeMe123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
        log_success "Created default WiFi config (SSID: Onyx_Gateway)"
    fi

    # 3. FIX: Ensure Service is Active
    # We must point hostapd to this config file specifically
    DAEMON_CONF="/etc/default/hostapd"
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > "$DAEMON_CONF"

    systemctl unmask hostapd &> /dev/null
    systemctl enable hostapd &> /dev/null
    systemctl restart hostapd &> /dev/null
    
    if systemctl is-active hostapd &> /dev/null; then
        log_success "WiFi Service (hostapd) is RUNNING."
    else
        log_error "WiFi Service failed to start. Check /etc/hostapd/hostapd.conf"
    fi
}

system_install_raspap