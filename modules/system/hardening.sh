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

    # 1. Install dependency if missing
    apt-get install -y folder2ram &>/dev/null

    # 2. Corrected Command: Enable RAM mount for /var/log
    folder2ram -enable /var/log

    # 3. Mount the volatile partitions immediately
    folder2ram -mountall
    log_success "Forensic-Zero Active: Logs will vanish on power-off."
    
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