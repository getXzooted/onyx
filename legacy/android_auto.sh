#!/bin/bash
# ==============================================================================
# MODULE: System > Android Auto (Product Implementation)
# ==============================================================================

source "$ONYX_ROOT/modules/network/vlan_manager.sh"
source "$ONYX_ROOT/modules/network/firewall_builder.sh"
source "$ONYX_ROOT/modules/system/gadget_mode.sh"
source "$ONYX_ROOT/modules/system/aa_installer.sh"


# ------------------------------------------------------------------------------
# FUNCTION: product_deploy_aa_service
# DESCRIPTION: Automatically generates and installs the systemd service unit.
# ------------------------------------------------------------------------------
function product_deploy_aa_service() {
    local SERVICE_FILE="/etc/systemd/system/android-proxy-rs.service"
    local AA_IFACE="vlan${ONYX_AA_VLAN_ID}"

    log_step "Deploying Android Auto systemd service..."

    # Use 'cat' to write the service file using Script 1 variables
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Onyx Android Auto Proxy Service
After=network.target
Requires=network-online.target

[Service]
Type=simple
User=root
# Dynamically injected variables from onyx.yml
ExecStart=/usr/local/bin/android-proxy-rs --port ${ONYX_AA_PROXY_PORT} --interface ${AA_IFACE}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_success "Service unit deployed to $SERVICE_FILE"
}

function product_setup_android_auto() {
    log_header "PRODUCT SETUP: ANDROID AUTO"

    # 1. Variables from Script 1 (onyx.yml)
    local AA_IFACE="vlan${ONYX_AA_VLAN_ID}"
    local PARENT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    local DHCP_PREFIX=$(echo "$ONYX_AA_VLAN_IP" | cut -d. -f1-3)

    # 2. Network Infrastructure
    vlan_create "$PARENT_IFACE" "$ONYX_AA_VLAN_ID" "$AA_IFACE"
    vlan_assign_ip "$AA_IFACE" "${ONYX_AA_VLAN_IP}/24"
    vlan_setup_dhcp "$AA_IFACE" "$DHCP_PREFIX" "1.1.1.1"

    # 3. Security & Uplink Logic
    network_open_auto_ports "$AA_IFACE" "aa"

    if [[ "$ONYX_AA_ISOLATE_NETWORK" == "true" ]]; then
        network_isolate_interfaces "$AA_IFACE" "uap0"
    fi

    # STRATEGY TOGGLE: VPN vs DIRECT
    if [[ "$ONYX_AA_VPN_ONLY" == "true" ]]; then
        network_grant_vpn_access "$AA_IFACE"
    else
        # Car Mode: Allow direct internet access for Wireless Android Auto stability
        network_grant_direct_access "$AA_IFACE"
    fi

    # 4. Gadget Mode Check
    if [[ "$ONYX_AA_GADGET_MODE" == "true" ]]; then
        system_enable_usb_gadget
    fi

    # 5. Auto-Deploy & Start Service
    system_install_aa_binary
    product_deploy_aa_service

    # 6. Service Activation
    log_step "Starting android-proxy-rs..."
    systemctl enable --now android-proxy-rs
    
    log_success "ANDROID AUTO READY (VLAN: $AA_IFACE)."
}