#!/bin/bash
# ==============================================================================
# MODULE: Network > Firewall Builder (Script 2 Library)
# PURPOSE: Advanced injection logic for isolation and uplink strategies.
# ==============================================================================

if [ -z "$ONYX_ROOT" ]; then exit 1; fi

# ------------------------------------------------------------------------------
# FUNCTION: network_isolate_interfaces
# ARGS: [iface_a] [iface_b]
# DESCRIPTION: Prevents traffic between two internal networks.
# ------------------------------------------------------------------------------
function network_isolate_interfaces() {
    local IF_A=$1
    local IF_B=$2
    local SCRIPT="/usr/local/bin/safety-net.sh"

    log_info "Hardening Firewall: Creating isolation barrier between $IF_A and $IF_B..."

    if [ ! -f "$SCRIPT" ]; then
        log_error "Firewall script $SCRIPT not found. Run provision first."
        return 1
    fi

    # Inject drop rules before the NAT section
    sed -i "/# 9. NAT/i # Isolation: $IF_A <-> $IF_B" "$SCRIPT"
    sed -i "/# 9. NAT/i \$IPT -A FORWARD -i $IF_A -o $IF_B -j DROP" "$SCRIPT"
    sed -i "/# 9. NAT/i \$IPT -A FORWARD -i $IF_B -o $IF_A -j DROP" "$SCRIPT"
    
    log_success "Isolation barrier injected into $SCRIPT."
}

# ------------------------------------------------------------------------------
# FUNCTION: network_grant_vpn_access (VPN ONLY)
# ARGS: [iface]
# DESCRIPTION: Forces all traffic from an interface through the WireGuard tunnel.
# ------------------------------------------------------------------------------
function network_grant_vpn_access() {
    local IFACE=$1
    local SCRIPT="/usr/local/bin/safety-net.sh"
    
    log_step "Configuring VPN-ONLY access for $IFACE via wg0..."

    # Inject 'allow' rules strictly for the VPN tunnel
    sed -i "/# 9. NAT/i # VPN-Only Access: $IFACE" "$SCRIPT"
    sed -i "/# 9. NAT/i \$IPT -A FORWARD -i $IFACE -o wg0 -j ACCEPT" "$SCRIPT"
    
    log_success "VPN-Only access granted to $IFACE."
}

# ------------------------------------------------------------------------------
# FUNCTION: network_grant_direct_access (DIRECT WAN / CAR MODE)
# ARGS: [iface]
# DESCRIPTION: Allows an interface to bypass the VPN and use the physical uplink.
# ------------------------------------------------------------------------------
function network_grant_direct_access() {
    local IFACE=$1
    local SCRIPT="/usr/local/bin/safety-net.sh"
    
    # Detect the physical WAN interface (e.g., eth0 or wlan0)
    local PARENT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

    log_step "Configuring DIRECT access for $IFACE (Bypassing VPN via $PARENT_IFACE)..."

    # 1. Inject Forwarding Rule
    sed -i "/# 9. NAT/i # Direct WAN Access (Car Mode): $IFACE via $PARENT_IFACE" "$SCRIPT"
    sed -i "/# 9. NAT/i \$IPT -A FORWARD -i $IFACE -o $PARENT_IFACE -j ACCEPT" "$SCRIPT"

    # 2. Inject NAT/Masquerade Rule for the physical interface
    # We append this to the end of the script to ensure it is processed correctly
    echo -e "\n# NAT for Direct Access ($IFACE)\n\$IPT -t nat -A POSTROUTING -o $PARENT_IFACE -j MASQUERADE" >> "$SCRIPT"
    
    log_success "Direct WAN access granted to $IFACE. VPN bypassed."
}

# ------------------------------------------------------------------------------
# FUNCTION: network_open_auto_ports
# ARGS: [iface] [mode (aa|apple)]
# DESCRIPTION: Opens handshake and streaming ports on the local interface.
# ------------------------------------------------------------------------------
function network_open_auto_ports() {
    local IFACE=$1
    local MODE=$2
    local SCRIPT="/usr/local/bin/safety-net.sh"

    log_step "Opening $MODE handshake ports on $IFACE..."

    if [[ "$MODE" == "aa" ]]; then
        # Wireless Android Auto: Handshake (TCP/UDP) + Proxy Port
        # These variables must exist in your onyx.yml
        sed -i "/# 9. NAT/i # Android Auto Handshake ($IFACE)" "$SCRIPT"
        sed -i "/# 9. NAT/i \$IPT -A INPUT -i $IFACE -p tcp -m multiport --dports $ONYX_AA_TCP_PORTS -j ACCEPT" "$SCRIPT"
        sed -i "/# 9. NAT/i \$IPT -A INPUT -i $IFACE -p udp -m multiport --dports $ONYX_AA_UDP_PORTS -j ACCEPT" "$SCRIPT"
        sed -i "/# 9. NAT/i \$IPT -A INPUT -i $IFACE -p tcp --dport $ONYX_AA_PROXY_PORT -j ACCEPT" "$SCRIPT"
    fi

    # (Future: Add Apple CarPlay port logic here)
    
    log_success "Automotive ports opened on $IFACE."
}