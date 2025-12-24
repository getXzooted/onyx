#!/bin/bash
# /opt/onyx/lib/hardening_rules.sh
# ONYX V2: Dedicated Security Rule Library

# --- KERNEL RULES ---

function check_disable_ipv6() {
    local INTENT=$1
    [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6)" == "1" ]] && return 0 || return 1
}

function apply_disable_ipv6() {
    log_step "Applying IPv6 Lockdown..."
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null
}

function check_ignore_redirects() {
    [[ "$(sysctl -n net.ipv4.conf.all.accept_redirects)" == "0" ]] && return 0 || return 1
}

function apply_ignore_redirects() {
    sysctl -w net.ipv4.conf.all.accept_redirects=0 > /dev/null
}

# --- SYSTEM RULES ---

function check_bluetooth_locked() {
    local INTENT=$1
    if [[ "$INTENT" == "true" ]]; then
        systemctl is-active bluetooth &>/dev/null && return 1 || return 0
    fi
    return 0
}

function apply_bluetooth_locked() {
    if [[ "$1" == "true" ]]; then
        log_step "Locking Bluetooth Hardware..."
        systemctl disable --now bluetooth &>/dev/null
        grep -q "dtoverlay=disable-bt" /boot/firmware/config.txt || echo "dtoverlay=disable-bt" >> /boot/firmware/config.txt
    fi
}

# --- NETWORK RULES ---

function check_isolation_barrier() {
    iptables -C FORWARD -i vlan20 -o uap0 -j DROP &>/dev/null && return 0 || return 1
}

function apply_isolation_barrier() {
    if [[ "$1" == "true" ]]; then
        # Calls tactical function from execution lib
        build_rule FORWARD -i vlan20 -o uap0 -j DROP
    fi
}