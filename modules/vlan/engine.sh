#!/bin/bash
# MODULE: VLAN > Engine (Template Driven)

function vlan_apply_state() {
    local NAME=$1
    local ID=$2
    local SUBNET=$3   # e.g., 10.50.0.1/24
    local RANGE=$4    # e.g., 10.50.0.50,10.50.0.255
    local DNS=${5:-"127.0.0.1"}
    local PARENT=$ONYX_PHY_LAN # Discovered LAN interface

    log_header "APPLYING VLAN STATE: $NAME"

    # 1. Interface Management
    if ip link show "$NAME" > /dev/null 2>&1; then
        ip link delete "$NAME"
    fi
    ip link add link "$PARENT" name "$NAME" type vlan id "$ID"
    ip link set "$NAME" up
    ip addr add "$SUBNET" dev "$NAME"

    # 2. Template Generation
    local CONF_FILE="/etc/dnsmasq.d/10-$NAME.conf"
    log_step "Generating DHCP via template..."
    
    cp "$ONYX_VLAN_TEMPLATE" "$CONF_FILE"
    sed -i "s/{{NAME}}/$NAME/g" "$CONF_FILE"
    sed -i "s/{{RANGE}}/$RANGE/g" "$CONF_FILE"
    sed -i "s/{{DNS}}/$DNS/g" "$CONF_FILE"

    systemctl restart dnsmasq
    log_success "VLAN $NAME (ID: $ID) is now ACTIVE."
}