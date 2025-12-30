#!/bin/bash
# CORE: Onyx Provision Script
# Handles the provisioning phase of Onyx Gateway installation.

check_root
check_env

mkdir -p /etc/onyx/firewall/
mkdir -p /etc/unbound/unbound.conf.d/

log_header "--- PROVISIONING SYSTEM ---"
            
log_warning "Waiting for system time synchronization..."
    
# Loop until the OS explicitly reports 'yes'
until [ "$(timedatectl show -p NTPSynchronized --value)" == "yes" ]; do
    echo -n "."
    sleep 1
done
    
echo ""
log_success "Time synchronized. Proceeding."
    
log_info "Waiting for active internet connection..."
until ping -c 1 -W 2 google.com > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
log_success "Connection Confirmed. Proceeding..."

# 1. DNS Services (Unbound)
log_info "Phase 2a: DNS Services"
source "$MODULES_DIR/dns/configure_unbound.sh"
source "$MODULES_DIR/dns/set_routing.sh"
# (Assuming these scripts auto-run their main functions or you add them here)

# --- PHASE 2 DNS LOCKDOWN ---
log_info "Redirecting Gateway DNS to Local Unbound..."

# Force local loopback
echo "nameserver 127.0.0.1" > /etc/resolv.conf

# THE POLISH: Make the file immutable (NetworkManager can't touch it)
chattr +i /etc/resolv.conf
log_success "Gateway DNS Locked to 127.0.0.1"

# 2. RaspAP Hotspot (The Web Interface)
#log_info "Phase 2b: RaspAP Hotspot"
#source "$MODULES_DIR/system/raspap.sh"
log_info "Phase 2b: Native Hotspot"
source "$MODULES_DIR/network/hotspot.sh"
    
# 3. Dashboard (The CLI Monitor)
log_info "Phase 2c: CLI Dashboard"
source "$MODULES_DIR/system/dashboard.sh"
system_install_dashboard

# 5. Secure Uplink (Final Lock)
log_info "Phase 2e: Securing Uplink"
source "$MODULES_DIR/system/tuning.sh"
system_secure_uplink
    
# 6. Cleanup (Delete the resume service)
system_cleanup_resume
    
log_success "ONYX INSTALLATION COMPLETE."
log_info "Run 'sudo onyx monitor' to view dashboard."