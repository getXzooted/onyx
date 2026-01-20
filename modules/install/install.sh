#!/bin/bash
# CORE: Onyx Installation Script
# Handles the phased installation and setup of Onyx Gateway.

# 1. Install Dependencies
log_info "Phase 1: System Dependencies"
if [ ! -f "$MODULES_DIR/install/dependencies.sh" ]; then
    log_error "Missing dependencies script!"
    exit 1
else
    log_step "Installing core dependencies..."
    source "$MODULES_DIR/install/dependencies.sh"
fi

# 2. Install Bootstrap Service
log_info "Phase 2: Bootstrap Controller Service"
if [ ! -f "$MODULES_DIR/install/bootstrap.sh" ]; then
    log_error "Missing bootstrap script!"
    exit 1
else
    log_step "Setting up bootstrap service..."
    source "$MODULES_DIR/install/bootstrap.sh"
    bootstrap
fi

# 3. Auto-Provisioning Service (The Boot Watcher)
log_info "Phase 3: Auto-Provisioning Service"
if [ ! -f "$MODULES_DIR/provision/ingest.sh" ]; then
    log_error "Missing ingest script!"
    exit 1
else
    log_step "Setting up auto-provisioning service..."
    source "$MODULES_DIR/provision/ingest.sh"
    
fi

# 4. Asset Synchronization & Network Hardening
log_info "Phase 4: Setup Assets & Network Hardening"

log_step "Provisioning Network"
$ONYX_ROOT/bin/onyx provision

log_step "Configuring Network"
$ONYX_ROOT/bin/onyx config

log_step "Hardening Network"
# $ONYX_ROOT/bin/onyx network repair

# 5. We also reboot in case no drag-and-drop happens.
log_info "System will reboot now to continue installation..."

echo "3"
sleep 1
echo "2"
sleep 1
echo "1"
sleep 1
reboot