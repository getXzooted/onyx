#!/bin/bash
# MODULE: System > Resume Logic
# PURPOSE: Handles state persistence across the mandatory kernel reboot.

RESUME_MARKER="/var/opt/onyx_resume_pending"
RESUME_SERVICE="/etc/systemd/system/onyx-resume.service"

function system_check_resume_state() {
    # If the marker exists, we are returning from a reboot (Phase 2)
    if [ -f "$RESUME_MARKER" ]; then
        return 0 
    else
        return 1
    fi
}

function system_setup_resume() {
    log_header "SCHEDULING REBOOT RESUME"
    
    # 1. Create the Marker
    # This acts as the memory for the next boot
    touch "$RESUME_MARKER"
    
    # 2. Create the Systemd Service
    # We use the global symlink '/usr/local/bin/onyx' because your install.sh
    # guarantees it exists before we reach this point.
    log_step "Creating one-time systemd service..."
    
    cat <<EOF > "$RESUME_SERVICE"
[Unit]
Description=Onyx Installer Resume Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/local/bin/onyx install > /var/log/onyx_resume.log 2>&1'
StandardOutput=journal+console
User=root

[Install]
WantedBy=multi-user.target
EOF

    # 3. Enable it
    systemctl enable onyx-resume.service
    log_success "Resume service armed."
    
    # log_warning "SYSTEM WILL REBOOT IN 5 SECONDS..."
    # sleep 5
    # reboot
    # We let the ingest/provision function handle the reboot now to create drag and drop flow.
}

function system_cleanup_resume() {
    log_step "Cleaning up resume artifacts..."
    
    # 1. Disable & Remove Service
    # We stop it from ever running again
    systemctl disable onyx-resume.service 2>/dev/null
    rm -f "$RESUME_SERVICE"
    systemctl daemon-reload
    
    # 2. Remove Marker
    rm -f "$RESUME_MARKER"
    
    log_success "Resume sequence completed."
}