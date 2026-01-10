#!/bin/bash
# MODULE: Network > Safety Net (Firewall)
# Generates the 'Kill Switch' firewall script and service.

if [ -z "$ONYX_ROOT" ]; then
    echo "Error: This module must be run via the Onyx CLI."
    exit 1
fi

function network_safety_net() {
    log_header "CONFIGURING SAFETY NET (FIREWALL)"

    # Ensure variables are loaded into this shell session
    load_config

    # 1. CHECK VARIABLES
    if [[ -z "$ONYX_VPN_ENDPOINT" || -z "$ONYX_VPN_PORT" ]]; then
        log_error "Missing VPN Endpoint/Port. Cannot generate firewall rules."
        return 1
    fi

    TARGET_SCRIPT="/usr/local/bin/safety-net.sh"
    SERVICE_FILE="/etc/systemd/system/safety-net.service"

    log_step "Generating firewall logic at $TARGET_SCRIPT..."

    # 2. GENERATE MINIMAL ENFORCER SCRIPT
    # Instead of a massive block of strings, this script now sources 
    # your core Onyx libraries to apply rules dynamically.
    cat <<EOF > "$TARGET_SCRIPT"
#!/bin/bash
# ONYX Boot-time Safety Net
source "$ONYX_ROOT/env.sh"
source "$ONYX_ROOT/lib/hardening_execution.sh"

# 1. Flush and Set Default Deny
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -F
iptables -t nat -F

# 2. Handover to the Hardening Engine
# This will execute every rule in hardening.yml in linear order.
/usr/local/bin/onyx network repair
EOF

    chmod +x "$TARGET_SCRIPT"

    # 3. GENERATE SYSTEMD SERVICE
    log_step "Creating systemd service..."
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Safety Net Firewall Rules
After=network.target

[Service]
Type=oneshot
ExecStart=$TARGET_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable safety-net &> /dev/null
    log_success "Safety Net refactored and service enabled."
}

network_safety_net