#!/bin/bash
# ==============================================================================
# MODULE: Network > VLAN Manager (Generic Library)
# PURPOSE: Hardware-agnostic functions for VLAN lifecycle management.
# ==============================================================================

# Ensure the module is running within the Onyx environment
if [ -z "$ONYX_ROOT" ]; then
    echo "CRITICAL ERROR: This library must be sourced by the Onyx CLI."
    exit 1
fi

# ------------------------------------------------------------------------------
# FUNCTION: vlan_create
# ARGS: [parent_iface] [vlan_id] [vlan_name]
# DESCRIPTION: Creates a tagged 802.1Q VLAN interface.
# ------------------------------------------------------------------------------
function vlan_create() {
    local PARENT=$1
    local ID=$2
    local NAME=$3

    log_step "Initializing VLAN $NAME (ID: $ID) on interface $PARENT..."

    # 1. Cleanup: Remove existing interface if it exists to prevent 'File exists' errors
    if ip link show "$NAME" > /dev/null 2>&1; then
        log_warning "Interface $NAME already exists. Cleaning up old instance..."
        ip link delete "$NAME"
    fi

    # 2. Creation: Use 'ip link' to create the tagged interface
    ip link add link "$PARENT" name "$NAME" type vlan id "$ID"
    
    # 3. Activation: Bring the interface up
    if ip link set "$NAME" up; then
        log_success "VLAN interface $NAME created and set to UP."
    else
        log_error "Failed to activate VLAN interface $NAME."
        return 1
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: vlan_assign_ip
# ARGS: [vlan_name] [ip_cidr]
# DESCRIPTION: Assigns a static IP address to the specified interface.
# ------------------------------------------------------------------------------
function vlan_assign_ip() {
    local NAME=$1
    local IP=$2 # Expects format "10.40.0.1/24"

    log_step "Configuring static IP $IP for $NAME..."

    if ip addr add "$IP" dev "$NAME"; then
        log_success "IP address $IP successfully assigned to $NAME."
    else
        log_error "Failed to assign IP $IP to $NAME. Check for conflicts."
        return 1
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: vlan_setup_dhcp
# ARGS: [vlan_name] [subnet_prefix] [dns_server]
# DESCRIPTION: Generates a dedicated dnsmasq configuration for the VLAN.
# ------------------------------------------------------------------------------
function vlan_setup_dhcp() {
    local NAME=$1
    local PREFIX=$2 # e.g., "10.40.0"
    local DNS=$3
    local CONF="/etc/dnsmasq.d/10-$NAME.conf"

    log_step "Generating DHCP pool for $NAME ($PREFIX.50 - $PREFIX.255)..."

    # Create the dnsmasq config file for this specific interface
    cat <<EOF > "$CONF"
# Onyx Dynamic DHCP Config for $NAME
interface=$NAME
dhcp-range=$PREFIX.50,$PREFIX.255,12h
dhcp-option=6,$DNS
no-resolv
EOF

    # Restart dnsmasq to apply the new pool
    if systemctl restart dnsmasq; then
        log_success "DHCP service active for $NAME. DNS directed to $DNS."
    else
        log_error "Failed to restart dnsmasq for interface $NAME."
        return 1
    fi
}