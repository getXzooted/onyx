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

function system_setup_resume() {
    log_header 
    local TARGET_CMD="${1:-provision}" # Default to provision if none provided
    local SERVICE_FILE="/etc/systemd/system/onyx-resume.service"

    
    log_step "Creating systemd service"
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Onyx Resume Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/onyx $TARGET_CMD
StandardOutput=journal+console
StandardError=inherit
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable onyx-resume.service
}