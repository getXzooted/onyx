#!/bin/bash
# CORE: Onyx Installation Script
# Handles the phased installation and setup of Onyx Gateway.

check_root
check_env

log_header "STARTING INSTALLATION (PHASE 1)"
            
# 1. System Bootstrap (Updates)
log_info "Phase 1: System Bootstrap & Hardening"
source "$MODULES_DIR/system/bootstrap.sh"
source "$MODULES_DIR/system/hardening.sh"

# 2. Memory Guard (Rule-based)
log_info "Phase 2: Applying Memory Guard..."
source "$ONYX_ROOT/lib/hardening_rules.sh"
apply_memory_guard "true" 

# 3. Schedule Reboot & Resume
log_info "Phase 3: Scheduling Reboot & Resume"
source "$MODULES_DIR/system/resume.sh"
system_setup_resume "provision"

# 4. Auto-Provisioning Service (The USB Watcher)
log_info "Phase 4: Auto-Provisioning Service"
source "$MODULES_DIR/provision/install_service.sh"
source "$MODULES_DIR/provision/ingest.sh"

# 5. We also reboot in case no drag-and-drop happens.
log_info "System will reboot now to continue installation..."
sleep 3
reboot