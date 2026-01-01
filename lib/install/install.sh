#!/bin/bash
# CORE: Onyx Installation Script
# Handles the phased installation and setup of Onyx Gateway.

check_root
check_env

log_header "--- STARTING INSTALLATION ---"

# 1. Install Dependencies
log_info "Phase 1: System Dependencies"
source "$ONYX_ROOT/lib/install/dependencies.sh"

# 2. Install Bootstrap Service
log_info "Phase 2: Bootstrap Controller Service"
source "$ONYX_ROOT/lib/install/bootstrap.sh"

# 3. Auto-Provisioning Service (The Boot Watcher)
log_info "Phase 3: Auto-Provisioning Service"
source "$ONYX_ROOT/lib/provision/ingest.sh"

# 4. Asset Synchronization & Network Hardening
log_info "Phase 4: Setup Assets & Network Hardening"

log_step "Provisioning Network"
$ONYX_ROOT/bin/onyx provision

log_step "Configuring Network"
$ONYX_ROOT/bin/onyx config

log_step "Hardening Network"
$ONYX_ROOT/bin/onyx network repair

# 5. We also reboot in case no drag-and-drop happens.
log_info "System will reboot now to continue installation..."

echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1
reboot