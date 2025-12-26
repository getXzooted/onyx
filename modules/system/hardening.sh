#!/bin/bash
# MODULE: System Hardening
# Applies kernel-level security settings.
# Includes strict port from V1 + V2 Security Upgrades.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function system_hardening() {
    log_header "SYSTEM HARDENING"

    # --- ONYX STEALTH: LOG-TO-RAM ---
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
    echo "tmpfs /var/log" > /etc/folder2ram/folder2ram.conf

    # 3. Enable Systemd Service
    folder2ram -enablesystemd &>/dev/null

    # 4. Critical: Release /var/log so it can be mounted without a reboot
    log_step "Releasing /var/log from systemd-journald..."
    journalctl --relinquish-var &>/dev/null
    
    # 5. Mount the partitions
    if folder2ram -mountall; then
        journalctl --flush &>/dev/null
        log_success "Forensic-Zero Active: Logs now live in RAM."
    else
        log_warning "Forensic-Zero: Mount failed (Target Busy). A reboot is REQUIRED."
    fi

    # --- KERNEL HARDENING RULES ---   
    SYSCTL_FILE="/etc/sysctl.d/99-onyx-hardening.conf"
    
    log_step "Applying Kernel parameters to $SYSCTL_FILE..."
    
    cat <<EOF > "$SYSCTL_FILE"
# --- V1 PORTED RULES ---
# 1. IP Forwarding (Required for Router function)
net.ipv4.ip_forward=1

# 2. Security (Ignore redirects, log martians)
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.log_martians=1

# 3. Disable IPv6 (External Interfaces)
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1

# --- V2 SECURITY UPGRADES ---
# 4. Disable IPv6 on Loopback (Consistency fix)
net.ipv6.conf.lo.disable_ipv6=1

# 5. Do NOT Send Redirects (Prevents routing manipulation)
net.ipv4.conf.all.send_redirects=0
EOF

    # Apply changes immediately
    sysctl -p "$SYSCTL_FILE" &> /dev/null
    
    if [ $? -eq 0 ]; then
        log_success "Kernel hardening applied (Enhanced V2)."
    else
        log_error "Failed to apply sysctl rules."
    fi
}

system_hardening