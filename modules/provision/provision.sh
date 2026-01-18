#!/bin/bash
# CORE: Onyx Provision Script
# Handles the provisioning phase of Onyx Gateway installation.

check_root
check_env

if [ ! -d "/etc/onyx/firewall/" ]; then
    log_info "Creating Firewall Directory..."
    mkdir -p /etc/onyx/firewall/
fi

if [ ! -d "/etc/unbound/unbound.conf.d/" ]; then
    log_info "Creating Unbound Config Directory..."
    mkdir -p /etc/unbound/unbound.conf.d/
fi
            
# 1. DNS Services (Unbound)
log_info "Phase 2a: DNS Services"
source "$MODULES_DIR/dns/configure_unbound.sh"
source "$MODULES_DIR/dns/set_routing.sh"

# --- PHASE 1b DNS LOCKDOWN ---
log_info "Redirecting Gateway DNS to Local Unbound..."
echo "nameserver 127.0.0.1" > /etc/resolv.conf

# Make the file immutable (NetworkManager can't touch it)
chattr +i /etc/resolv.conf
log_success "Gateway DNS Locked to 127.0.0.1"

# 2. Native Hotspot
log_info "Phase 2: Native Hotspot"
source "$MODULES_DIR/network/hotspot.sh"
    
# 3. Dashboard (The CLI Monitor)
log_info "Phase 3: CLI Dashboard"
source "$MODULES_DIR/system/dashboard.sh"
system_install_dashboard

# 4. Secure Uplink (Final Lock)
log_info "Phase 4: Securing Uplink"
source "$MODULES_DIR/system/tuning.sh"
system_secure_uplink
    
# 5. Finalize Provisioning   
log_success "ONYX INSTALLATION COMPLETE."
log_info "Run 'sudo onyx monitor' to view dashboard."