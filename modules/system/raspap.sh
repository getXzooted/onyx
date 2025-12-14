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
        
        cat <<EOF > "$HOSTAPD_CONF"
interface=uap0
driver=nl80211
country_code=US
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
    # Create virtual interface (Dynamic Detection)
    
    # 1. Find the physical interface name (e.g., wlan0)
    # We look for the first interface starting with 'wl' (wireless)
    PHY_INT=$(ls /sys/class/net | grep ^wl | head -n 1)
    
    # Fallback to wlan0 if detection fails
    if [ -z "$PHY_INT" ]; then PHY_INT="wlan0"; fi

    # TARGETED FIX: Lock NetworkManager out of uap0 (Corporate Standard)
    # This ensures the OS respects our custom IP assignment and doesn't wipe it.
    if [ -d "/etc/NetworkManager/conf.d" ]; then
        log_step "Configuring NetworkManager to ignore uap0..."
        echo -e "[keyfile]\nunmanaged-devices=interface-name:uap0" > /etc/NetworkManager/conf.d/99-onyx-uap0.conf
        systemctl reload NetworkManager &> /dev/null
    fi

    # 2. Persistence Override (Create Interface + Assign IP)
    # Add the virtual AP interface to the detected device
    # This works regardless of whether it is wlan0, wlan1, etc.
    iw dev "$PHY_INT" interface add uap0 type __ap &> /dev/null

    mkdir -p /etc/systemd/system/hostapd.service.d
    
    echo "[Service]" > /etc/systemd/system/hostapd.service.d/override.conf
    
    # 1. Create the virtual interface (Ignore error if exists)
    echo "ExecStartPre=-/usr/sbin/iw dev "$PHY_INT" interface add uap0 type __ap" >> /etc/systemd/system/hostapd.service.d/override.conf

    # 2. ASSIGN GATEWAY IP (The Missing Link)
    # This matches the default RaspAP DHCP range (10.3.141.x)
    echo "ExecStartPre=-/usr/sbin/ip addr add 10.3.141.1/24 dev uap0" >> /etc/systemd/system/hostapd.service.d/override.conf
    
    # 3. Bring the interface UP
    echo "ExecStartPre=-/usr/sbin/ip link set uap0 up" >> /etc/systemd/system/hostapd.service.d/override.conf
    
    systemctl daemon-reload

    systemctl restart hostapd &> /dev/null
    
    if systemctl is-active hostapd &> /dev/null; then
        log_success "WiFi Service (hostapd) is RUNNING."
    else
        log_error "WiFi Service failed to start. Check /etc/hostapd/hostapd.conf"
    fi

    # TARGETED FIX: Configure DHCP (Universal Fix)
    # 1. Fix the hidden RaspAP config (The Root Cause)
    if [ -d "/etc/dnsmasq.d" ]; then
        log_step "Updating RaspAP DHCP configs to uap0..."
        # Find any file saying 'wlan0' and swap it to 'uap0'
        grep -rl "interface=wlan0" /etc/dnsmasq.d/ | xargs sed -i 's/interface=wlan0/interface=uap0/g'
    fi

    # 2. Fix the main system config (The Safety Net - from your code)
    if [ -f "/etc/dnsmasq.conf" ]; then
        log_step "Updating Main DHCP config..."
        # Uncomment and force uap0
        sed -i 's/^#interface=.*/interface=uap0/' /etc/dnsmasq.conf
        sed -i 's/^interface=.*/interface=uap0/' /etc/dnsmasq.conf
    fi
    
    # 3. Apply Changes
    systemctl restart dnsmasq
}

system_install_raspap