#!/bin/bash
# lib/install/bootstrap.sh

function bootstrap() {
    log_header "ARMING SOVEREIGN CONTROLLER"
    
    local SERVICE_FILE="/etc/systemd/system/onyx.service"
    
    log_step "Creating permanent /etc/systemd/system/onyx.service..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Onyx Sovereign Gateway Controller
After=network-online.target local-fs.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/onyx boot
StandardOutput=journal+console
StandardError=journal+console
User=root
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable onyx.service
    log_success "Controller armed. Initial entry: 'onyx boot'"
}