#!/bin/bash
# CORE: ONYX FOUNDATIONAL FIREWALL RULES
# Purpose: Establish baseline firewall rules for system integrity and VPN operation.

function apply_established_related() {
    log_step "Allowing Established/Related Traffic..."
    build_rule INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    build_rule OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    build_rule FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
}

function apply_localhost_access() {
    log_step "Allowing Localhost (lo) access..."
    build_rule INPUT -i lo -j ACCEPT
    build_rule OUTPUT -o lo -j ACCEPT
}

function apply_dhcp_access() {
    log_step "Allowing DHCP (67:68) traffic..."
    build_rule INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
    build_rule OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
}

function apply_rfc1918_access() {
    log_step "Allowing Universal Local Access (RFC1918)..."
    build_rule INPUT -s 10.0.0.0/8 -j ACCEPT
    build_rule OUTPUT -d 10.0.0.0/8 -j ACCEPT
    build_rule INPUT -s 172.16.0.0/12 -j ACCEPT
    build_rule OUTPUT -d 172.16.0.0/12 -j ACCEPT
    build_rule INPUT -s 192.168.0.0/16 -j ACCEPT
    build_rule OUTPUT -d 192.168.0.0/16 -j ACCEPT
}

function apply_vpn_transport() {
    log_step "Opening VPN Transport to $ONYX_VPN_ENDPOINT..."
    build_rule OUTPUT -d "$ONYX_VPN_ENDPOINT" -p udp --dport "$ONYX_VPN_PORT" -j ACCEPT
}

function apply_tunnel_integrity() {
    log_step "Permitting Internal Tunnel Traffic (wg0)..."
    build_rule INPUT -i wg0 -j ACCEPT
    build_rule OUTPUT -o wg0 -j ACCEPT
    build_rule FORWARD -i wg0 -j ACCEPT
    build_rule FORWARD -o wg0 -j ACCEPT
    # NAT Masquerade
    iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
}



# --- FOUNDATION AUDIT WORKERS ---

function check_established_related() {
    # Verify the rule exists in all three core chains
    iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null && \
    iptables -C FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null && return 0
    return 1
}

function check_localhost_access() {
    # Verify local loopback is permitted
    iptables -C INPUT -i lo -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -o lo -j ACCEPT &>/dev/null && return 0
    return 1
}

function check_dhcp_access() {
    # Verify DHCP ports are open for hotspot client IP assignment
    iptables -C INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT &>/dev/null && return 0
    return 1
}

function check_rfc1918_access() {
    # Verify all internal subnet ranges are permitted
    iptables -C INPUT -s 10.0.0.0/8 -j ACCEPT &>/dev/null && \
    iptables -C INPUT -s 172.16.0.0/12 -j ACCEPT &>/dev/null && \
    iptables -C INPUT -s 192.168.0.0/16 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -d 10.0.0.0/8 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -d 172.16.0.0/12 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -d 192.168.0.0/16 -j ACCEPT &>/dev/null && return 0
    return 1
}

function check_vpn_transport() {
    # Verify the tunnel's specific physical exit point is permitted
    iptables -C OUTPUT -d "$ONYX_VPN_ENDPOINT" -p udp --dport "$ONYX_VPN_PORT" -j ACCEPT &>/dev/null && return 0
    return 1
}

function check_tunnel_integrity() {
    # 1. Verify general tunnel traffic flow (INPUT, OUTPUT, FORWARD)
    iptables -C INPUT -i wg0 -j ACCEPT &>/dev/null && \
    iptables -C OUTPUT -o wg0 -j ACCEPT &>/dev/null && \
    iptables -C FORWARD -i wg0 -j ACCEPT &>/dev/null && \
    iptables -C FORWARD -o wg0 -j ACCEPT &>/dev/null && \
    # 2. Verify NAT Masquerading is active for the tunnel
    iptables -t nat -C POSTROUTING -o wg0 -j MASQUERADE &>/dev/null && return 0
    return 1
}