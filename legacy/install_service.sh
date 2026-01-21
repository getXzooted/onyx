#!/bin/bash
# MODULE: Provisioning > Install Service
# Sets up the systemd unit that watches for config files on boot.

function provision_install_service() {
    log_header "INSTALLING AUTO-PROVISION SERVICE"
    
    SERVICE_FILE="/etc/systemd/system/onyx-provision.service"
    SCRIPT_PATH="$ONYX_ROOT/modules/provision/ingest.sh"
    
    # We need a wrapper to ensure ONYX_ROOT is set when run by systemd
    WRAPPER_PATH="/usr/local/bin/onyx-watcher"
    
    # 1. Create Wrapper Script
    cat <<EOF > "$WRAPPER_PATH"
#!/bin/bash
export ONYX_ROOT="/opt/onyx"
source "\$ONYX_ROOT/core/logger.sh"
source "\$ONYX_ROOT/modules/provision/ingest.sh"
EOF
    chmod +x "$WRAPPER_PATH"

    # 2. Create Systemd Unit
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Onyx Auto-Provisioning Watcher
After=network.target local-fs.target

[Service]
Type=oneshot
ExecStart=$WRAPPER_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # 3. Enable Service
    systemctl daemon-reload
    systemctl enable onyx-provision &> /dev/null
    log_success "Auto-Provisioning service enabled."
}

provision_install_service