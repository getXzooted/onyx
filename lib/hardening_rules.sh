#!/bin/bash
# /opt/onyx/lib/hardening_rules.sh
# ONYX V2: Dedicated Security Rule Library

# --- KERNEL RULES ---

function check_mac_stealth() {
    # Verify if uap0 is using its permanent hardware MAC or a randomized one
    local CURRENT=$(cat /sys/class/net/uap0/address 2>/dev/null)
    local PERM=$(ethtool -P uap0 2>/dev/null | awk '{print $3}')
    
    # If they match, the MAC is NOT rotated (Drifted)
    if [[ "$CURRENT" == "$PERM" ]]; then
        return 1
    fi
    return 0
}

function apply_mac_stealth() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying MAC Stealth (Rotating uap0)..."
        
        # 1. Stop the Wireless Stack to prevent BSSID mismatch
        systemctl stop hostapd dnsmasq &>/dev/null
        
        # 2. Rotate the MAC
        ip link set uap0 down
        macchanger -r uap0 &>/dev/null
        ip link set uap0 up
        
        # 3. Restart services to broadcast the new identity
        systemctl start dnsmasq hostapd &>/dev/null
        
        log_success "MAC Stealth Applied: uap0 identity rotated."
    fi
}

function check_fingerprint_protection() {
    # Verify if TCP Timestamps are disabled (Reduced OS signature)
    [[ "$(sysctl -n net.ipv4.tcp_timestamps)" == "0" ]] && return 0 || return 1
}

function apply_fingerprint_protection() {
    if [[ "$1" == "true" ]]; then
        log_step "Standardizing TCP Stack (Anti-Fingerprinting)..."
        # 1. Disable RFC1323 timestamps to hide OS-specific uptime/timing
        sysctl -w net.ipv4.tcp_timestamps=0 > /dev/null
        # 2. Enable Window Scaling (Standard behavior)
        sysctl -w net.ipv4.tcp_window_scaling=1 > /dev/null
    fi
}

function check_disable_ipv6() {
    local INTENT=$1
    local CURRENT=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
    # If YAML says true (disable) but kernel says 0 (enabled), it's a drift
    [[ "$INTENT" == "true" && "$CURRENT" == "0" ]] && return 1
    return 0
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

function check_ip_forwarding() {
    [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] && return 0 || return 1
}

function apply_ip_forwarding() {
    if [[ "$1" == "true" ]]; then
        sysctl -w net.ipv4.ip_forward=1 > /dev/null
    fi
}

function check_log_martians() {
    [[ "$(sysctl -n net.ipv4.conf.all.log_martians)" == "1" ]] && return 0 || return 1
}

function apply_log_martians() {
    if [[ "$1" == "true" ]]; then
        sysctl -w net.ipv4.conf.all.log_martians=1 > /dev/null
    fi
}

function check_no_send_redirects() {
    [[ "$(sysctl -n net.ipv4.conf.all.send_redirects)" == "0" ]] && return 0 || return 1
}

function apply_no_send_redirects() {
    if [[ "$1" == "true" ]]; then
        sysctl -w net.ipv4.conf.all.send_redirects=0 > /dev/null
    fi
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

function check_forensic_zero() {
    # 1. Verify if /var/log is a mountpoint
    if mountpoint -q /var/log; then
        # 2. STRICT: It MUST be a tmpfs (RAM-disk) to pass audit
        if mount | grep "/var/log" | grep -q "tmpfs"; then
            return 0
        fi
    fi
    # If not a mountpoint or not tmpfs, it is drifted
    return 1
}

function apply_forensic_zero() {
    if [[ "$1" == "true" ]]; then
        # --- ONYX STEALTH: LOG-TO-RAM ---
        log_step "Engaging Forensic-Zero (Log-to-RAM)..."
        log_info "Redirecting logs to Volatile RAM..."

        # 1. Manual Download (Apt-get fails on Pi Zero for this tool)
        if ! command -v folder2ram &> /dev/null; then
            log_step "Downloading folder2ram v0.4.1..."
            wget -qO /sbin/folder2ram https://raw.githubusercontent.com/bobafetthotmail/folder2ram/master/debian_package/sbin/folder2ram
            chmod +x /sbin/folder2ram
        fi

        # 2. Manual Configuration (Since -enable is missing in 0.4.1)
        log_step "Configuring /var/log for RAM-disk..."
        mkdir -p /etc/folder2ram
        # Format: type [space] path [space] options
        echo "/var/log tmpfs size=128M,nodev,nosuid,noatime" > /etc/folder2ram/folder2ram.conf

        # 3. Enable Systemd Service
        folder2ram -enablesystemd &>/dev/null

        # 4. Stop loggers so we can mount /var/log
        log_step "Unlocking /var/log from system loggers..."
        systemctl stop rsyslog unbound dnsmasq hostapd &>/dev/null
        journalctl --relinquish-var &>/dev/null
        
        # 5. Mount the partitions
        if folder2ram -mountall; then
            # 6. Success: Flush and Restore services
            journalctl --flush &>/dev/null
            systemctl start rsyslog unbound dnsmasq hostapd &>/dev/null
            log_success "Forensic-Zero Active: Logs are now in RAM."
        else
            # 7. Fallback: Restore loggers if mount failed
            systemctl start rsyslog unbound dnsmasq hostapd &>/dev/null
            log_error "Forensic-Zero: Mount failed (Target Busy). Reboot required."
        fi
    fi
}

# --- NETWORK RULES ---

function check_safety_net() {
    # 1. Verify Default Policy is DROP
    if ! iptables -L FORWARD -n | grep -q "policy DROP"; then
        return 1
    fi
    
    # 2. Verify VPN Endpoint rule is present in OUTPUT chain
    if ! iptables -L OUTPUT -n | grep -q "$ONYX_VPN_ENDPOINT"; then
        return 1
    fi
    
    return 0
}

function apply_safety_net() {
    if [[ "$1" == "true" ]]; then
        log_step "Repairing Safety Net (Firewall Sync)..."
        
        # 1. LOAD THE GENERATOR: Ensure the module is available
        source "$ONYX_ROOT/modules/network/safety_net.sh"
        
        # 2. EXECUTE: Now that the file is guaranteed to exist, run it to restore internet
        if [ -x "/usr/local/bin/safety-net.sh" ]; then
            /usr/local/bin/safety-net.sh
        else
            log_error "Safety Net repair failed: Script could not be built."
        fi
    fi
}

function check_webrtc_lockdown() {
    iptables -C OUTPUT -p udp -m multiport --dports 3478,19302,5349 -j DROP &>/dev/null && return 0 || return 1
}

function apply_webrtc_lockdown() {
    log_step "Blocking WebRTC STUN/TURN traffic..."
    build_rule OUTPUT -p udp -m multiport --dports 3478,19302,5349 -j DROP
}

function check_isolation_barrier() {
    iptables -C FORWARD -i vlan20 -o uap0 -j DROP &>/dev/null && return 0 || return 1
}

function apply_isolation_barrier() {
    if [[ "$1" == "true" ]]; then
        # Calls tactical function from execution lib
        build_rule FORWARD -i vlan20 -o uap0 -j DROP
    fi
}

function check_default_deny() {
    # Check if the global policy is DROP
    iptables -L FORWARD -n | grep -q "policy DROP" && return 0 || return 1
}

function apply_default_deny() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying Global Default Deny policy..."
        iptables -P FORWARD DROP
    fi
}

function check_ttl_masking() {
    # Verify if TTL mangling is active
    iptables -t mangle -L POSTROUTING -n | grep -q "TTL set to" && return 0 || return 1
}

function apply_ttl_masking() {
    if [[ "$1" == "true" ]]; then
        log_step "Applying TTL Stealth Masking..."
        iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
    fi
}