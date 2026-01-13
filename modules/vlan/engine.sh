#!/bin/bash
# MODULE: VLAN > Engine (Master Unified)

# --- WORKER: BOOTSTRAP HARDWARE (From hotspot.sh) ---
function vlan_bootstrap_hardware() {
    local PARENT=$1
    local IP=$2
    local PHY_INT=$(ls /sys/class/net | grep ^wl | head -n 1)
    [[ -z "$PHY_INT" ]] && PHY_INT="wlan0"

    if [ -d "/etc/NetworkManager/conf.d" ]; then
        echo -e "[keyfile]\nunmanaged-devices=interface-name:$PARENT" > /etc/NetworkManager/conf.d/99-onyx-$PARENT.conf
        systemctl reload NetworkManager &> /dev/null
    fi

    mkdir -p /etc/systemd/system/hostapd.service.d
    cat <<EOF > /etc/systemd/system/hostapd.service.d/override.conf
[Service]
ExecStartPre=-/usr/sbin/iw dev $PHY_INT interface add $PARENT type __ap
ExecStartPre=-/usr/sbin/ip addr add $IP/24 dev $PARENT
ExecStartPre=-/usr/sbin/ip link set $PARENT up
EOF
    systemctl daemon-reload
}

# --- WORKER: INITIALIZE HOSTAPD ---
function vlan_init_hostapd() {
    local IFACE=$1
    local SSID=$(yq e '.wifi_ssid' "$ONYX_YAML")
    local PASS=$(yq e '.wifi_password' "$ONYX_YAML")
    
    cat <<EOF > /etc/hostapd/hostapd.conf
interface=$IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
wpa=2
wpa_passphrase=$PASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
}

# --- WORKER: KERNEL HARDWARE ---
function vlan_apply_hardware() {
    local NAME=$1; local ID=$2; local SUBNET=$3
    local PARENT=${ONYX_LAN_IFACE:-"uap0"} 
    ip link delete "$NAME" 2>/dev/null
    if ip link add link "$PARENT" name "$NAME" type vlan id "$ID"; then
        ip link set "$NAME" up
        ip addr add "$SUBNET" dev "$NAME"
    fi
}

# --- WORKER: DHCP GENERATION ---
function vlan_generate_dhcp() {
    local NAME=$1; local RANGE=$2; local DNS=${3:-"127.0.0.1"}
    local CONF="/etc/dnsmasq.d/10-vlan-$NAME.conf"
    if [[ -f "$ONYX_VLAN_TEMPLATE" ]]; then
        cp "$ONYX_VLAN_TEMPLATE" "$CONF"
        sed -i "s/{{NAME}}/$NAME/g" "$CONF"
        sed -i "s/{{RANGE}}/$RANGE/g" "$CONF"
        sed -i "s/{{DNS}}/$DNS/g" "$CONF"
    fi
}

# --- WORKER: WIRELESS BROADCAST ---
function vlan_update_wireless() {
    local NAME=$1; local SSID=$2; local PASS=$3
    {
        echo -e "\n# --- VIRTUAL BSS ($NAME) ---\nbss=$NAME\nssid=$SSID\nwpa=2\nwpa_passphrase=$PASS\nwpa_key_mgmt=WPA-PSK\nrsn_pairwise=CCMP"
    } >> /etc/hostapd/hostapd.conf
}