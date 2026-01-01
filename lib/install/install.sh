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

# 3. Auto-Provisioning Service (The USB Watcher)
log_info "Phase 3: Auto-Provisioning Service"
#source "$MODULES_DIR/provision/ingest.sh"
source "$ONYX_ROOT/lib/provision/ingest.sh"

# 4. Asset Synchronization & Network Hardening
log_info "Phase 4: Asset Synchronization & Network Hardening"

$ONYX_ROOT/bin/onyx provision
$ONYX_ROOT/bin/onyx config
$ONYX_ROOT/bin/onyx network repair

# 5. We also reboot in case no drag-and-drop happens.
log_info "System will reboot now to continue installation..."
sleep 3
reboot