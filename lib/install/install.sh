#!/bin/bash
# CORE: Onyx Installation Script
# Handles the phased installation and setup of Onyx Gateway.

check_root
check_env

log_header "--- STARTING INSTALLATION ---"

# 1. Install Dependencies
log_info "Phase 1: System Dependencies"
source "$ONYX_ROOT/lib/install/dependencies.sh"


# 2. Schedule Reboot & Resume
log_info "Phase 2: Scheduling Reboot & Resume"
source "$MODULES_DIR/system/resume.sh"
system_setup_resume "provision"

# 3. Auto-Provisioning Service (The USB Watcher)
log_info "Phase 3: Auto-Provisioning Service"
source "$MODULES_DIR/provision/install_service.sh"
source "$MODULES_DIR/provision/ingest.sh"

# 4. Asset Synchronization & Network Hardening
log_info "Phase 4: Asset Synchronization & Network Hardening"
$ONYX_ROOT/bin/onyx network repair

# 5. We also reboot in case no drag-and-drop happens.
log_info "System will reboot now to continue installation..."
sleep 3
reboot