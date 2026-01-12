#!/bin/bash
# MODULE: VLAN > Engine (Atomic & Template Driven)

# --- WORKER 1: KERNEL HARDWARE ---
function vlan_apply_hardware() {
    local NAME=$1
    local ID=$2
    local SUBNET=$3
    # Use the logical LAN identity from vars.sh
    local PARENT=${ONYX_LAN_IFACE:-"uap0"} 

    log_step "Building Kernel Interface: $NAME (VLAN $ID) on $PARENT..."

    # Cleanup existing to prevent 'File exists' errors
    ip link delete "$NAME" 2>/dev/null
    
    # Create and Activate Tagged Interface
    if ip link add link "$PARENT" name "$NAME" type vlan id "$ID"; then
        ip link set "$NAME" up
        ip addr add "$SUBNET" dev "$NAME"
        log_success "Interface $NAME is UP."
    else
        log_error "Failed to create VLAN interface $NAME."
        return 1
    fi
}

# --- WORKER 2: DHCP GENERATION ---
function vlan_generate_dhcp() {
    local NAME=$1
    local RANGE=$2
    local DNS=${3:-"127.0.0.1"}
    # Standardized naming for the sync cleaner
    local CONF="/etc/dnsmasq.d/10-vlan-$NAME.conf"

    log_step "Deploying DHCP for $NAME via Template..."
    
    # Use the established DHCP template
    if [[ -f "$ONYX_VLAN_TEMPLATE" ]]; then
        cp "$ONYX_VLAN_TEMPLATE" "$CONF"
        sed -i "s/{{NAME}}/$NAME/g" "$CONF"
        sed -i "s/{{RANGE}}/$RANGE/g" "$CONF"
        sed -i "s/{{DNS}}/$DNS/g" "$CONF"
    else
        log_error "VLAN DHCP Template not found at $ONYX_VLAN_TEMPLATE"
        return 1
    fi
}

# --- WORKER 3: WIRELESS BROADCAST ---
function vlan_update_wireless() {
    local VLAN_NAME=$1
    local SSID=$2
    local PASS=$3
    local HOSTAPD_CONF="/etc/hostapd/hostapd.conf"
    
    log_step "Broadcasting SSID: $SSID on interface $VLAN_NAME..."

    # To be uniform, this should eventually use the multi_ssid.conf template.
    # For now, we append a clean BSS block.
    {
        echo ""
        echo "# --- VIRTUAL BSS ($VLAN_NAME) ---"
        echo "bss=$VLAN_NAME"
        echo "ssid=$SSID"
        echo "wpa=2"
        echo "wpa_passphrase=$PASS"
        echo "wpa_key_mgmt=WPA-PSK"
        echo "rsn_pairwise=CCMP" # Modern security only
    } >> "$HOSTAPD_CONF"
}