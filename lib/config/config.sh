#!/bin/bash
# CORE: Onyx Config Script
# Handles the configuration phase of Onyx Gateway installation.

check_root
check_env

log_header "APPLYING CONFIGURATION"
# Check if a config file path is provided as an argument
if [ -n "$2" ]; then
        source "$MODULES_DIR/provision/ingest.sh"
        # Pass the file path to the ingest function
        provision_ingest "$2"
        exit $?
fi

# 1. LOAD CONFIG
# We need the variables (ONYX_VPN_ENDPOINT, etc.) to be loaded first!
if [ -f "$CORE_DIR/config_parser.sh" ]; then
        load_config
fi

# 2. RUN MODULES
log_info "Phase 1: Configure VPN"
source "$MODULES_DIR/vpn/wireguard/configure.sh"

log_info "Phase 2: Configure Firewall (Safety Net)"
source "$MODULES_DIR/network/safety_net.sh"

# 3. SECURE UPLINK (The "Hotel" Fix)
# This detects the NEW hotel connection and forces it to use safe DNS.
log_info "Phase 3: Secure Uplink (DNS Lock)"
source "$MODULES_DIR/system/tuning.sh"
system_secure_uplink

# 4. VERIFY
# Simple check to see if services are active
if systemctl is-enabled safety-net &> /dev/null; then
        log_success "System is PROVISIONED and LOCKED DOWN."
        log_info "Reboot recommended to apply all changes."
else
        log_error "Provisioning failed. Firewall service not enabled."
fi

# 5. Run Network Repair (Fix any drift)
log_info "Running Network Repair to fix any drift..."
$ONYX_ROOT/bin/onyx network repair