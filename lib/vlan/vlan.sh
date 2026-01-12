#!/bin/bash
# LIB: VLAN CLI Controller

source "$VLAN_MODULES_DIR/manager.sh"

function vlan_sync_all() {
    log_header "SYNCHRONIZING VLAN SEGMENTS"
    
    # Extract segments from onyx.yml using yq
    local SEGMENTS=$(yq e '.networks.segments[].name' "$ONYX_YAML")
    
    for NAME in $SEGMENTS; do
        local ID=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .id" "$ONYX_YAML")
        local SUBNET=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .subnet" "$ONYX_YAML")
        local RANGE=$(yq e ".networks.segments[] | select(.name == \"$NAME\") | .dhcp_range" "$ONYX_YAML")
        
        vlan_apply_state "$NAME" "$ID" "$SUBNET" "$RANGE"
    done
}

# Add switch case for CLI arguments
case "$1" in
    sync)   vlan_sync_all ;;
    *)      echo "Usage: onyx vlan {sync}" ;;
esac